//
//  StoryNarrationController.swift
//  JuniorGlobe
//

import AVFoundation
import Combine
import CryptoKit
import Foundation
import NaturalLanguage

enum StoryNarrationSegment: String, Codable, Sendable {
    case headline
    case summary
    case backgroundBrief
}

struct StoryNarrationSentence: Equatable, Identifiable, Sendable {
    let segment: StoryNarrationSegment
    let index: Int
    let text: String

    var id: String {
        "\(segment.rawValue)-\(index)"
    }
}

struct StoryNarrationHighlight: Equatable, Sendable {
    let requestID: String
    let segment: StoryNarrationSegment
    let sentenceIndex: Int
}

struct StoryNarrationRequest: Equatable, Sendable {
    let id: String
    let edition: AppEdition
    let ageBand: AgeBand
    let headline: String
    let summary: String
    let backgroundBrief: String?
}

enum StoryNarrationFailureReason: String, Equatable, Sendable {
    case serviceUnavailable
    case timedOut
    case invalidResponse
    case generationFailed
}

enum StoryNarrationStage: Equatable, Sendable {
    case requestingScript
    case generatingAudio
    case preparingPlayback
    case playing
    case failed(StoryNarrationFailureReason)
}

struct StoryNarrationStatus: Equatable, Sendable {
    let requestID: String
    let stage: StoryNarrationStage
    let progress: Double?

    var isPreparing: Bool {
        switch stage {
        case .requestingScript, .generatingAudio, .preparingPlayback:
            return true
        case .playing, .failed:
            return false
        }
    }

    var isPlaying: Bool {
        if case .playing = stage {
            return true
        }

        return false
    }

    var failureReason: StoryNarrationFailureReason? {
        if case let .failed(reason) = stage {
            return reason
        }

        return nil
    }

    var normalizedProgress: Double {
        let fallbackProgress: Double
        switch stage {
        case .requestingScript:
            fallbackProgress = 0.16
        case .generatingAudio:
            fallbackProgress = 0.62
        case .preparingPlayback:
            fallbackProgress = 0.9
        case .playing:
            fallbackProgress = 1
        case .failed:
            fallbackProgress = 0
        }

        return min(max(progress ?? fallbackProgress, 0), 1)
    }
}

struct RemoteNarrationSentencePayload: Codable, Equatable, Sendable {
    let index: Int
    let text: String
}

struct RemoteNarrationSegmentPayload: Codable, Equatable, Sendable {
    let segment: StoryNarrationSegment
    let transcript: String
    let sentences: [RemoteNarrationSentencePayload]
}

struct RemoteSpeechRequest: Codable, Equatable, Sendable {
    let model: String
    let voice: String
    let input: String
    let responseFormat: String
    let speed: Double
    let instructions: String?

    enum CodingKeys: String, CodingKey {
        case model
        case voice
        case input
        case responseFormat = "response_format"
        case speed
        case instructions
    }
}

private struct RemoteNarrationCacheIdentity: Codable, Equatable, Sendable {
    let edition: String
    let ageBand: String
    let model: String
    let voice: String
    let input: String
    let responseFormat: String
    let speed: Double
    let instructions: String?
    let segments: [RemoteNarrationSegmentPayload]
}

@MainActor
final class StoryNarrationController: NSObject, ObservableObject {
    @Published private(set) var activeStoryID: String?
    @Published private(set) var activeHighlight: StoryNarrationHighlight?
    @Published private(set) var activeStatus: StoryNarrationStatus?

    private struct SpokenFragment: Equatable, Sendable {
        let text: String
        let language: SourceContentLanguage
    }

    private struct ActiveNarrationTiming: Equatable, Sendable {
        let highlight: StoryNarrationHighlight
        let startSeconds: Double
        let endSeconds: Double
    }

    private struct ActiveNarrationContext {
        let request: StoryNarrationRequest
        let segments: [RemoteNarrationSegmentPayload]
    }

    private enum RemoteNarrationClientError: Error {
        case serviceUnavailable
        case invalidResponse
        case timedOut
        case generationFailed

        var failureReason: StoryNarrationFailureReason {
            switch self {
            case .serviceUnavailable:
                return .serviceUnavailable
            case .invalidResponse:
                return .invalidResponse
            case .timedOut:
                return .timedOut
            case .generationFailed:
                return .generationFailed
            }
        }
    }

    private let session: URLSession
    private let narrationBaseURL: URL?
    private let audioCacheDirectoryURL: URL
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var playerTimeObserver: Any?
    private var playerEndObserver: NSObjectProtocol?
    private var playerFailureObserver: NSObjectProtocol?
    private var playerAudioFileURL: URL?
    private var activeSentenceTimings: [ActiveNarrationTiming] = []
    private var activeNarrationContext: ActiveNarrationContext?
    private var localSpeechHighlightsByUtteranceID: [ObjectIdentifier: StoryNarrationHighlight] = [:]
    private var localSpeechUtteranceIDsInOrder: [ObjectIdentifier] = []
    private var isStoppingLocalSpeech = false
    private var narrationTask: Task<Void, Never>?

    init(
        session: URLSession = .shared,
        narrationBaseURL: URL? = AppConfig.remoteNarrationBaseURL
    ) {
        self.session = session
        self.narrationBaseURL = narrationBaseURL
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.audioCacheDirectoryURL = cachesURL
            .appendingPathComponent("JuniorGlobe/NarrationAudioCache", isDirectory: true)
        super.init()
        speechSynthesizer.delegate = self
        prepareNarrationCacheDirectoryIfNeeded()
    }

    func toggleNarration(for request: StoryNarrationRequest) {
        if let status = status(for: request.id), status.isPreparing || status.isPlaying {
            stop()
        } else {
            speak(request)
        }
    }

    func isNarrating(_ storyID: String) -> Bool {
        status(for: storyID)?.isPlaying == true
    }

    func status(for storyID: String) -> StoryNarrationStatus? {
        guard activeStatus?.requestID == storyID else {
            return nil
        }

        return activeStatus
    }

    func stop() {
        narrationTask?.cancel()
        narrationTask = nil
        cleanupPlayer()
        stopLocalSpeechIfNeeded()
        activeNarrationContext = nil
        activeStoryID = nil
        activeHighlight = nil
        activeStatus = nil
    }

    private func speak(_ request: StoryNarrationRequest) {
        stop()
        configureAudioSessionIfNeeded()
        activeStoryID = request.id

        let payload = Self.remoteJobRequest(for: request)
        let segments = Self.remoteNarrationSegments(for: request)
        let cacheKey = Self.remoteNarrationCacheKey(
            payload: payload,
            segments: segments,
            edition: request.edition,
            ageBand: request.ageBand
        )
        activeNarrationContext = ActiveNarrationContext(request: request, segments: segments)
        activeStatus = StoryNarrationStatus(
            requestID: request.id,
            stage: .requestingScript,
            progress: 0.12
        )

        narrationTask = Task { [weak self] in
            await self?.runRemoteNarration(
                request,
                payload,
                segments: segments,
                cacheKey: cacheKey,
                requestID: request.id
            )
        }
    }

    private func configureAudioSessionIfNeeded() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            return
        }
        #endif
    }

    private func runRemoteNarration(
        _ request: StoryNarrationRequest,
        _ payload: RemoteSpeechRequest,
        segments: [RemoteNarrationSegmentPayload],
        cacheKey: String,
        requestID: String
    ) async {
        do {
            try Task.checkCancellation()
            if let cachedAudioURL = cachedNarrationAudioURL(for: cacheKey) {
                do {
                    try await preparePlayback(
                        audioFileURL: cachedAudioURL,
                        segments: segments,
                        requestID: requestID
                    )
                    narrationTask = nil
                    return
                } catch {
                    removeCachedNarrationAudio(for: cacheKey)
                }
            }

            guard let narrationBaseURL else {
                startLocalNarration(
                    for: request,
                    segments: segments,
                    requestID: requestID,
                    fallbackReason: .serviceUnavailable
                )
                narrationTask = nil
                return
            }

            activeStatus = StoryNarrationStatus(
                requestID: requestID,
                stage: .generatingAudio,
                progress: 0.68
            )
            let audioData = try await requestSpeechAudio(payload, baseURL: narrationBaseURL)
            try Task.checkCancellation()
            let audioFileURL = try cacheAudioData(audioData, for: cacheKey)
            try await preparePlayback(
                audioFileURL: audioFileURL,
                segments: segments,
                requestID: requestID
            )
            narrationTask = nil
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .timedOut {
            startLocalNarration(
                for: request,
                segments: segments,
                requestID: requestID,
                fallbackReason: .timedOut
            )
        } catch let error as RemoteNarrationClientError {
            startLocalNarration(
                for: request,
                segments: segments,
                requestID: requestID,
                fallbackReason: error.failureReason
            )
        } catch {
            startLocalNarration(
                for: request,
                segments: segments,
                requestID: requestID,
                fallbackReason: .invalidResponse
            )
        }
    }

    private func requestSpeechAudio(
        _ payload: RemoteSpeechRequest,
        baseURL: URL
    ) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("api/speech")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw RemoteNarrationClientError.serviceUnavailable
        }

        guard data.isEmpty == false else {
            throw RemoteNarrationClientError.generationFailed
        }

        return data
    }

    private func preparePlayback(
        audioFileURL: URL,
        segments: [RemoteNarrationSegmentPayload],
        requestID: String
    ) async throws {
        activeStatus = StoryNarrationStatus(
            requestID: requestID,
            stage: .preparingPlayback,
            progress: 0.96
        )

        let asset = AVURLAsset(url: audioFileURL)
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw RemoteNarrationClientError.generationFailed
        }

        let duration = try? await asset.load(.duration)
        let durationSeconds = duration?.seconds ?? .zero
        let resolvedDuration = durationSeconds.isFinite && durationSeconds > 0
            ? durationSeconds
            : Self.fallbackPlaybackDuration(for: segments)

        cleanupPlayer()

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.playerAudioFileURL = audioFileURL
        self.activeSentenceTimings = Self.estimatedSentenceTimings(
            from: segments,
            totalDuration: resolvedDuration,
            requestID: requestID
        )
        installPlayerObservers(for: player, requestID: requestID)
        player.play()

        activeStatus = StoryNarrationStatus(
            requestID: requestID,
            stage: .playing,
            progress: nil
        )
    }

    private func installPlayerObservers(
        for player: AVPlayer,
        requestID: String
    ) {
        removePlayerObservers()

        playerTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.12, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updateHighlight(at: time.seconds, requestID: requestID)
            }
        }

        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishPlayback()
            }
        }

        playerFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fallbackToLocalNarrationIfPossible(
                    reason: .generationFailed,
                    requestID: requestID
                )
            }
        }
    }

    private func updateHighlight(at seconds: Double, requestID: String) {
        guard activeStoryID == requestID else {
            return
        }

        if let timing = activeSentenceTimings.first(where: { seconds >= $0.startSeconds && seconds < $0.endSeconds }) {
            activeHighlight = timing.highlight
        } else {
            activeHighlight = nil
        }
    }

    private func finishPlayback() {
        narrationTask = nil
        cleanupPlayer()
        stopLocalSpeechIfNeeded()
        activeNarrationContext = nil
        activeStoryID = nil
        activeHighlight = nil
        activeStatus = nil
    }

    private func setFailure(
        _ reason: StoryNarrationFailureReason,
        requestID: String
    ) {
        narrationTask = nil
        cleanupPlayer()
        stopLocalSpeechIfNeeded()
        activeNarrationContext = nil
        activeStoryID = requestID
        activeHighlight = nil
        activeStatus = StoryNarrationStatus(
            requestID: requestID,
            stage: .failed(reason),
            progress: nil
        )
    }

    private func cleanupPlayer() {
        player?.pause()
        removePlayerObservers()
        player = nil
        playerAudioFileURL = nil
        activeSentenceTimings.removeAll()
    }

    private func fallbackToLocalNarrationIfPossible(
        reason: StoryNarrationFailureReason,
        requestID: String
    ) {
        guard
            let activeNarrationContext,
            activeNarrationContext.request.id == requestID
        else {
            setFailure(reason, requestID: requestID)
            return
        }

        startLocalNarration(
            for: activeNarrationContext.request,
            segments: activeNarrationContext.segments,
            requestID: requestID,
            fallbackReason: reason
        )
    }

    private func startLocalNarration(
        for request: StoryNarrationRequest,
        segments: [RemoteNarrationSegmentPayload],
        requestID: String,
        fallbackReason: StoryNarrationFailureReason
    ) {
        cleanupPlayer()
        stopLocalSpeechIfNeeded()

        let utterancePlans = Self.localSpeechUtterancePlans(
            for: request,
            segments: segments,
            requestID: requestID
        )
        guard utterancePlans.isEmpty == false else {
            setFailure(fallbackReason, requestID: requestID)
            return
        }

        activeNarrationContext = ActiveNarrationContext(request: request, segments: segments)
        activeStatus = StoryNarrationStatus(
            requestID: requestID,
            stage: .preparingPlayback,
            progress: 0.96
        )
        activeHighlight = nil
        localSpeechHighlightsByUtteranceID = Dictionary(
            uniqueKeysWithValues: utterancePlans.map { plan in
                (ObjectIdentifier(plan.utterance), plan.highlight)
            }
        )
        localSpeechUtteranceIDsInOrder = utterancePlans.map { ObjectIdentifier($0.utterance) }
        narrationTask = nil

        for plan in utterancePlans {
            speechSynthesizer.speak(plan.utterance)
        }

        activeStatus = StoryNarrationStatus(
            requestID: requestID,
            stage: .playing,
            progress: nil
        )
    }

    private func stopLocalSpeechIfNeeded() {
        isStoppingLocalSpeech = speechSynthesizer.isSpeaking || speechSynthesizer.isPaused
        if isStoppingLocalSpeech {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        localSpeechHighlightsByUtteranceID.removeAll()
        localSpeechUtteranceIDsInOrder.removeAll()
    }

    private func prepareNarrationCacheDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: audioCacheDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func cachedNarrationAudioURL(for cacheKey: String) -> URL? {
        let fileURL = audioCacheFileURL(for: cacheKey)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        touchNarrationCacheFile(at: fileURL)
        return fileURL
    }

    private func cacheAudioData(_ audioData: Data, for cacheKey: String) throws -> URL {
        prepareNarrationCacheDirectoryIfNeeded()
        let fileURL = audioCacheFileURL(for: cacheKey)

        do {
            try audioData.write(to: fileURL, options: [.atomic])
            touchNarrationCacheFile(at: fileURL)
            pruneNarrationCacheIfNeeded()
            return fileURL
        } catch {
            throw RemoteNarrationClientError.generationFailed
        }
    }

    private func audioCacheFileURL(for cacheKey: String) -> URL {
        audioCacheDirectoryURL
            .appendingPathComponent(cacheKey)
            .appendingPathExtension("mp3")
    }

    private func removeCachedNarrationAudio(for cacheKey: String) {
        try? FileManager.default.removeItem(at: audioCacheFileURL(for: cacheKey))
    }

    private func touchNarrationCacheFile(at fileURL: URL) {
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
    }

    private func pruneNarrationCacheIfNeeded() {
        let fileManager = FileManager.default
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: audioCacheDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let now = Date()
        let maxAge: TimeInterval = 14 * 24 * 60 * 60
        var regularFiles: [(url: URL, modifiedAt: Date)] = []

        for fileURL in fileURLs {
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else {
                continue
            }

            let modifiedAt = values?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modifiedAt) > maxAge {
                try? fileManager.removeItem(at: fileURL)
            } else {
                regularFiles.append((fileURL, modifiedAt))
            }
        }

        let maxFileCount = 80
        guard regularFiles.count > maxFileCount else {
            return
        }

        let overflow = regularFiles
            .sorted { $0.modifiedAt < $1.modifiedAt }
            .prefix(regularFiles.count - maxFileCount)

        for file in overflow {
            try? fileManager.removeItem(at: file.url)
        }
    }

    private func removePlayerObservers() {
        if let playerTimeObserver, let player {
            player.removeTimeObserver(playerTimeObserver)
        }
        playerTimeObserver = nil

        if let playerEndObserver {
            NotificationCenter.default.removeObserver(playerEndObserver)
        }
        playerEndObserver = nil

        if let playerFailureObserver {
            NotificationCenter.default.removeObserver(playerFailureObserver)
        }
        playerFailureObserver = nil
    }

    static func remoteJobRequest(for request: StoryNarrationRequest) -> RemoteSpeechRequest {
        let segments = remoteNarrationSegments(for: request)
        let transcript = segments
            .map(\.transcript)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return RemoteSpeechRequest(
            model: "gpt-4o-mini-tts",
            voice: remoteVoiceProfile(for: request.edition, ageBand: request.ageBand),
            input: transcript,
            responseFormat: "mp3",
            speed: remoteSpeechSpeed(for: request.edition, ageBand: request.ageBand),
            instructions: remoteSpeechInstructions(for: request.edition, ageBand: request.ageBand)
        )
    }

    static func remoteNarrationCacheKey(for request: StoryNarrationRequest) -> String {
        let payload = remoteJobRequest(for: request)
        let segments = remoteNarrationSegments(for: request)
        return remoteNarrationCacheKey(
            payload: payload,
            segments: segments,
            edition: request.edition,
            ageBand: request.ageBand
        )
    }

    static func remoteNarrationCacheKey(
        payload: RemoteSpeechRequest,
        segments: [RemoteNarrationSegmentPayload],
        edition: AppEdition,
        ageBand: AgeBand
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let identity = RemoteNarrationCacheIdentity(
            edition: edition.rawValue,
            ageBand: ageBand.rawValue,
            model: payload.model,
            voice: payload.voice,
            input: payload.input,
            responseFormat: payload.responseFormat,
            speed: payload.speed,
            instructions: payload.instructions,
            segments: segments
        )

        let blob = (try? encoder.encode(identity)) ?? Data(payload.input.utf8)

        let digest = SHA256.hash(data: blob)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func remoteNarrationSegments(for request: StoryNarrationRequest) -> [RemoteNarrationSegmentPayload] {
        let sources: [(StoryNarrationSegment, String?)] = [
            (.headline, request.headline),
            (.summary, request.summary),
            (.backgroundBrief, request.backgroundBrief)
        ]

        let segments = sources.compactMap { segment, rawText -> RemoteNarrationSegmentPayload? in
            let sentences = Self.sentences(
                in: rawText ?? "",
                edition: request.edition,
                segment: segment
            )

            guard sentences.isEmpty == false else {
                return nil
            }

            let spokenSentences = sentences.map { sentence in
                RemoteNarrationSentencePayload(
                    index: sentence.index,
                    text: remoteNarrationSentenceText(
                        from: sentence.text,
                        language: request.edition.contentLanguage
                    )
                )
            }

            let transcript = spokenSentences
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return RemoteNarrationSegmentPayload(
                segment: segment,
                transcript: transcript,
                sentences: spokenSentences
            )
        }

        return segments
    }

    private static func localSpeechUtterancePlans(
        for request: StoryNarrationRequest,
        segments: [RemoteNarrationSegmentPayload],
        requestID: String
    ) -> [(utterance: AVSpeechUtterance, highlight: StoryNarrationHighlight)] {
        segments.flatMap { payload in
            payload.sentences.map { sentence in
                let utterance = AVSpeechUtterance(string: sentence.text)
                utterance.voice = localSpeechVoice(for: request.edition)
                utterance.rate = localSpeechRate(for: request.ageBand)
                utterance.prefersAssistiveTechnologySettings = true
                utterance.postUtteranceDelay = 0.04

                let highlight = StoryNarrationHighlight(
                    requestID: requestID,
                    segment: payload.segment,
                    sentenceIndex: sentence.index
                )
                return (utterance, highlight)
            }
        }
    }

    private static func estimatedSentenceTimings(
        from segments: [RemoteNarrationSegmentPayload],
        totalDuration: Double,
        requestID: String
    ) -> [ActiveNarrationTiming] {
        let spokenSentences = segments.flatMap { payload in
            payload.sentences.map { sentence in
                (
                    segment: payload.segment,
                    index: sentence.index,
                    text: sentence.text
                )
            }
        }

        guard spokenSentences.isEmpty == false else {
            return []
        }

        let normalizedDuration = max(totalDuration, fallbackPlaybackDuration(for: segments))
        let sentenceCount = spokenSentences.count
        let minimumSentenceDuration = min(
            1.4,
            max(0.62, normalizedDuration / Double(max(sentenceCount, 1)) * 0.55)
        )
        let sentenceWeights = spokenSentences.map { spokenLengthWeight(for: $0.text) }
        let totalWeight = max(sentenceWeights.reduce(0, +), 1)
        var cursor = 0.0

        return spokenSentences.enumerated().map { offset, sentence in
            let desiredDuration = normalizedDuration * (sentenceWeights[offset] / totalWeight)
            let remainingCount = sentenceCount - offset - 1
            let remainingMinimumDuration = Double(remainingCount) * minimumSentenceDuration
            let maxAllowedDuration = max(minimumSentenceDuration, normalizedDuration - cursor - remainingMinimumDuration)
            let sentenceDuration = min(
                max(desiredDuration, minimumSentenceDuration),
                maxAllowedDuration
            )
            let endSeconds: Double
            if offset == sentenceCount - 1 {
                endSeconds = max(normalizedDuration + 0.18, cursor + sentenceDuration)
            } else {
                endSeconds = cursor + sentenceDuration
            }

            let timing = ActiveNarrationTiming(
                highlight: StoryNarrationHighlight(
                    requestID: requestID,
                    segment: sentence.segment,
                    sentenceIndex: sentence.index
                ),
                startSeconds: cursor,
                endSeconds: endSeconds
            )
            cursor = endSeconds
            return timing
        }
    }

    private static func fallbackPlaybackDuration(for segments: [RemoteNarrationSegmentPayload]) -> Double {
        let totalWeight = segments
            .flatMap(\.sentences)
            .map { spokenLengthWeight(for: $0.text) }
            .reduce(0, +)

        return max(3.2, totalWeight * 0.22)
    }

    private static func spokenLengthWeight(for text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return 1
        }

        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        if wordCount > 1 {
            return max(Double(wordCount) * 1.35, 3)
        }

        let cjkScalars = trimmed.unicodeScalars.filter {
            CharacterSet.whitespacesAndNewlines.contains($0) == false &&
            CharacterSet.punctuationCharacters.contains($0) == false
        }.count

        return max(Double(cjkScalars), 3)
    }

    private static func localSpeechVoice(for edition: AppEdition) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: localSpeechLanguageCode(for: edition))
    }

    private static func localSpeechLanguageCode(for edition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return "zh-TW"
        case .japanJa:
            return "ja-JP"
        case .unitedStatesEn:
            return "en-US"
        }
    }

    private static func localSpeechRate(for ageBand: AgeBand) -> Float {
        let multiplier: Double
        switch ageBand {
        case .ages6to9:
            multiplier = 0.82
        case .ages9to12:
            multiplier = 0.9
        }

        let baseRate = Double(AVSpeechUtteranceDefaultSpeechRate) * multiplier
        return Float(
            min(
                max(baseRate, Double(AVSpeechUtteranceMinimumSpeechRate)),
                Double(AVSpeechUtteranceMaximumSpeechRate)
            )
        )
    }

    private static func remoteVoiceProfile(for edition: AppEdition, ageBand: AgeBand) -> String {
        switch (edition, ageBand) {
        case (.taiwanZhHant, .ages6to9):
            return "marin"
        case (.taiwanZhHant, .ages9to12):
            return "marin"
        case (.japanJa, .ages6to9):
            return AppConfig.japaneseRemoteNarrationVoiceProfile
        case (.japanJa, .ages9to12):
            return AppConfig.japaneseRemoteNarrationVoiceProfile
        case (.unitedStatesEn, .ages6to9):
            return "shimmer"
        case (.unitedStatesEn, .ages9to12):
            return "marin"
        }
    }

    private static func remoteSpeechSpeed(for edition: AppEdition, ageBand: AgeBand) -> Double {
        switch (edition, ageBand) {
        case (.unitedStatesEn, .ages6to9):
            return 0.93
        case (.unitedStatesEn, .ages9to12):
            return 0.99
        case (.japanJa, .ages6to9):
            return 0.97
        case (.japanJa, .ages9to12):
            return 1.00
        case (.taiwanZhHant, .ages6to9):
            return 0.99
        case (.taiwanZhHant, .ages9to12):
            return 1.01
        }
    }

    private static func remoteSpeechInstructions(for edition: AppEdition, ageBand: AgeBand) -> String {
        switch (edition, ageBand) {
        case (.taiwanZhHant, .ages6to9):
            return "Speak in contemporary Taiwan Mandarin, using the natural pronunciation commonly heard from warm female elementary teachers in Taiwan. Keep the pacing smooth, lively, and relaxed for children. Read full phrases naturally, including English names commonly used in Taiwan. Avoid robotic pacing, clipped syllables, exaggerated announcer delivery, or any accent that does not sound local to Taiwan."
        case (.taiwanZhHant, .ages9to12):
            return "Speak in contemporary Taiwan Mandarin, using the natural pronunciation commonly heard from warm female youth news hosts in Taiwan. Keep the pacing smooth, clear, and confident. Read mixed English names naturally the way a Taiwanese speaker would. Avoid robotic pacing, clipped syllables, exaggerated announcer delivery, or any accent that does not sound local to Taiwan."
        case (.japanJa, .ages6to9):
            return "Speak in standard modern Japanese, using the natural pronunciation commonly heard from warm female elementary teachers in Japan. Keep the pacing smooth, lively, and relaxed for children. Use gentle Tokyo-style standard Japanese, and read borrowed English words naturally as they are commonly spoken in Japan. Avoid foreign-sounding delivery, clipped morae, over-enunciation, or theatrical intonation."
        case (.japanJa, .ages9to12):
            return "Speak in standard modern Japanese, using the natural pronunciation commonly heard from warm female youth news hosts in Japan. Keep the pacing smooth, clear, and confident. Use gentle Tokyo-style standard Japanese, and read borrowed English words naturally as they are commonly spoken in Japan. Avoid foreign-sounding delivery, clipped morae, over-enunciation, or theatrical intonation."
        case (.unitedStatesEn, .ages6to9):
            return "Speak in warm, natural American English for young children with a bright, friendly, female-presenting voice. Sound like a kind teacher reading a story aloud. Use natural conversational pacing, smooth phrase flow, gentle encouragement, and make each idea easy to follow. Do not over-separate words, and avoid any choppy or jagged digital tone."
        case (.unitedStatesEn, .ages9to12):
            return "Speak in natural American English for preteens with a clear, friendly, female-presenting voice. Sound like a warm youth news presenter. Use natural steady pacing, smooth sentence flow, sharper sentence endings, and lively but controlled energy. Do not over-separate words, and avoid any choppy or jagged digital tone."
        }
    }

    private static func remoteNarrationSentenceText(
        from sentence: String,
        language: SourceContentLanguage
    ) -> String {
        let fragments = spokenFragmentsDetailed(from: sentence, language: language)
        let joined = fragments.isEmpty
            ? sentence
            : fragments.map(\.text).joined(separator: language == .english ? " " : "")

        return joined
            .replacingOccurrences(of: "\\s+",
                                  with: " ",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sentences(
        in text: String,
        edition: AppEdition,
        segment: StoryNarrationSegment
    ) -> [StoryNarrationSentence] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return []
        }

        var sentences = naturalLanguageSentences(in: trimmed, edition: edition)

        if sentences.isEmpty {
            sentences = [trimmed]
        }

        return sentences.enumerated().map { index, sentence in
            StoryNarrationSentence(segment: segment, index: index, text: sentence)
        }
    }

    static func spokenFragments(from text: String, language: SourceContentLanguage) -> [String] {
        spokenFragmentsDetailed(from: text, language: language).map(\.text)
    }

    private static func spokenFragmentsDetailed(
        from text: String,
        language: SourceContentLanguage
    ) -> [SpokenFragment] {
        let normalized = normalizePunctuation(
            in: applyPhraseAliases(in: text, language: language),
            language: language
        )
        guard normalized.isEmpty == false else {
            return []
        }

        switch language {
        case .traditionalChinese, .japanese:
            return splitMixedLanguageFragments(in: normalized, language: language)
        case .english:
            guard let spoken = sanitizeMonolingualFragment(normalized, language: .english) else {
                return []
            }
            return [SpokenFragment(text: spoken, language: .english)]
        }
    }

    private static func normalizePunctuation(in text: String, language: SourceContentLanguage) -> String {
        var normalized = normalizeFullWidthASCII(in: text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "｡", with: language == .english ? ". " : "。")
            .replacingOccurrences(of: "—", with: language == .english ? ", " : "，")
            .replacingOccurrences(of: "–", with: language == .english ? ", " : "，")
            .replacingOccurrences(of: "…", with: language == .english ? ". " : "。")
            .replacingOccurrences(of: "•", with: language == .english ? ", " : "，")
            .replacingOccurrences(of: "●", with: language == .english ? ", " : "，")
            .replacingOccurrences(of: "「", with: "")
            .replacingOccurrences(of: "」", with: "")
            .replacingOccurrences(of: "『", with: "")
            .replacingOccurrences(of: "』", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "‘", with: "")
            .replacingOccurrences(of: "’", with: "")

        switch language {
        case .traditionalChinese:
            normalized = normalized
                .replacingOccurrences(of: "（", with: "，")
                .replacingOccurrences(of: "）", with: "，")
                .replacingOccurrences(of: "(", with: "，")
                .replacingOccurrences(of: ")", with: "，")
                .replacingOccurrences(of: "[", with: "，")
                .replacingOccurrences(of: "]", with: "，")
                .replacingOccurrences(of: ":", with: "，")
                .replacingOccurrences(of: "：", with: "，")
                .replacingOccurrences(of: ";", with: "，")
                .replacingOccurrences(of: "；", with: "，")
                .replacingOccurrences(of: "&", with: "和")
                .replacingOccurrences(of: "＆", with: "和")
                .replacingOccurrences(of: "/", with: "或")
                .replacingOccurrences(of: "+", with: "加")
                .replacingOccurrences(of: "＋", with: "加")
                .replacingOccurrences(of: "=", with: "等於")
                .replacingOccurrences(of: "＝", with: "等於")
                .replacingOccurrences(of: "@", with: "，")
                .replacingOccurrences(of: "＠", with: "，")
                .replacingOccurrences(of: "％", with: "百分之")
                .replacingOccurrences(of: "%", with: "百分之")
                .replacingOccurrences(of: "､", with: "，")
                .replacingOccurrences(of: "・", with: "，")
        case .japanese:
            normalized = normalized
                .replacingOccurrences(of: "（", with: "、")
                .replacingOccurrences(of: "）", with: "、")
                .replacingOccurrences(of: "(", with: "、")
                .replacingOccurrences(of: ")", with: "、")
                .replacingOccurrences(of: "[", with: "、")
                .replacingOccurrences(of: "]", with: "、")
                .replacingOccurrences(of: ":", with: "、")
                .replacingOccurrences(of: "：", with: "、")
                .replacingOccurrences(of: ";", with: "、")
                .replacingOccurrences(of: "；", with: "、")
                .replacingOccurrences(of: "&", with: "と")
                .replacingOccurrences(of: "＆", with: "と")
                .replacingOccurrences(of: "/", with: "または")
                .replacingOccurrences(of: "+", with: "プラス")
                .replacingOccurrences(of: "＋", with: "プラス")
                .replacingOccurrences(of: "=", with: "イコール")
                .replacingOccurrences(of: "＝", with: "イコール")
                .replacingOccurrences(of: "@", with: "、")
                .replacingOccurrences(of: "＠", with: "、")
                .replacingOccurrences(of: "％", with: "パーセント")
                .replacingOccurrences(of: "%", with: "パーセント")
                .replacingOccurrences(of: "､", with: "、")
                .replacingOccurrences(of: "・", with: "、")
        case .english:
            normalized = normalized
                .replacingOccurrences(of: "，", with: ", ")
                .replacingOccurrences(of: "。", with: ". ")
                .replacingOccurrences(of: "！", with: "! ")
                .replacingOccurrences(of: "？", with: "? ")
                .replacingOccurrences(of: "（", with: ", ")
                .replacingOccurrences(of: "）", with: ", ")
                .replacingOccurrences(of: "(", with: ", ")
                .replacingOccurrences(of: ")", with: ", ")
                .replacingOccurrences(of: "[", with: ", ")
                .replacingOccurrences(of: "]", with: ", ")
                .replacingOccurrences(of: ":", with: ", ")
                .replacingOccurrences(of: "：", with: ", ")
                .replacingOccurrences(of: ";", with: ", ")
                .replacingOccurrences(of: "；", with: ", ")
                .replacingOccurrences(of: "&", with: " and ")
                .replacingOccurrences(of: "＆", with: " and ")
                .replacingOccurrences(of: "/", with: " or ")
                .replacingOccurrences(of: "+", with: " plus ")
                .replacingOccurrences(of: "＋", with: " plus ")
                .replacingOccurrences(of: "=", with: " equals ")
                .replacingOccurrences(of: "＝", with: " equals ")
                .replacingOccurrences(of: "@", with: " at ")
                .replacingOccurrences(of: "＠", with: " at ")
                .replacingOccurrences(of: "％", with: " percent ")
                .replacingOccurrences(of: "%", with: " percent ")
                .replacingOccurrences(of: "､", with: ", ")
                .replacingOccurrences(of: "・", with: ", ")
        }

        normalized = normalized.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeFullWidthASCII(in text: String) -> String {
        let scalars = text.unicodeScalars.map { scalar -> UnicodeScalar in
            switch scalar.value {
            case 0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A:
                return UnicodeScalar(scalar.value - 0xFEE0) ?? scalar
            default:
                return scalar
            }
        }

        return String(String.UnicodeScalarView(scalars))
    }

    private static func splitMixedLanguageFragments(
        in text: String,
        language: SourceContentLanguage
    ) -> [SpokenFragment] {
        let expression = try? NSRegularExpression(pattern: #"[A-Za-z][A-Za-z0-9.&/\-+]*"#)
        guard let expression else {
            guard let spoken = sanitizeMonolingualFragment(text, language: language) else {
                return []
            }
            return [SpokenFragment(text: spoken, language: language)]
        }

        let nsText = text as NSString
        let matches = expression.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard matches.isEmpty == false else {
            guard let spoken = sanitizeMonolingualFragment(text, language: language) else {
                return []
            }
            return [SpokenFragment(text: spoken, language: language)]
        }

        var fragments: [SpokenFragment] = []
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let nativeSlice = nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                if let spoken = sanitizeMonolingualFragment(nativeSlice, language: language) {
                    fragments.append(SpokenFragment(text: spoken, language: language))
                }
            }

            let englishSlice = nsText.substring(with: match.range)
            if let spoken = blendedForeignFragment(from: englishSlice, targetLanguage: language) {
                fragments.append(SpokenFragment(text: spoken, language: language))
            } else if let spoken = sanitizeEmbeddedEnglishFragment(englishSlice) {
                fragments.append(SpokenFragment(text: spoken, language: .english))
            }

            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            let tail = nsText.substring(from: cursor)
            if let spoken = sanitizeMonolingualFragment(tail, language: language) {
                fragments.append(SpokenFragment(text: spoken, language: language))
            }
        }

        return fragments
    }

    private static func applyPhraseAliases(in text: String, language: SourceContentLanguage) -> String {
        let aliases = phraseAliases(for: language)
        guard aliases.isEmpty == false else {
            return text
        }

        return aliases
            .sorted { $0.key.count > $1.key.count }
            .reduce(text) { partial, entry in
                partial.replacingOccurrences(of: entry.key, with: entry.value)
            }
    }

    private static func phraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return mergedAliases(
                organizationPhraseAliases(for: .traditionalChinese),
                newsroomPhraseAliases(for: .traditionalChinese),
                brandPhraseAliases(for: .traditionalChinese),
                sportsPhraseAliases(for: .traditionalChinese),
                technologyPhraseAliases(for: .traditionalChinese),
                geographyPhraseAliases(for: .traditionalChinese),
                personPhraseAliases(for: .traditionalChinese)
            )
        case .japanese:
            return mergedAliases(
                organizationPhraseAliases(for: .japanese),
                newsroomPhraseAliases(for: .japanese),
                brandPhraseAliases(for: .japanese),
                sportsPhraseAliases(for: .japanese),
                technologyPhraseAliases(for: .japanese),
                geographyPhraseAliases(for: .japanese),
                personPhraseAliases(for: .japanese)
            )
        case .english:
            return mergedAliases(
                organizationPhraseAliases(for: .english),
                newsroomPhraseAliases(for: .english),
                brandPhraseAliases(for: .english),
                sportsPhraseAliases(for: .english),
                technologyPhraseAliases(for: .english),
                geographyPhraseAliases(for: .english),
                personPhraseAliases(for: .english),
                conceptPhraseAliasesForEnglish()
            )
        }
    }

    private static func blendedForeignFragment(
        from text: String,
        targetLanguage: SourceContentLanguage
    ) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "\\s+",
                                  with: " ",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.isEmpty == false else {
            return nil
        }

        let normalizedKey = cleaned
            .replacingOccurrences(of: "[^A-Za-z0-9]",
                                  with: "",
                                  options: .regularExpression)
            .uppercased()

        guard normalizedKey.isEmpty == false else {
            return nil
        }

        let compactLatinToken = cleaned
            .replacingOccurrences(of: "[^A-Za-z0-9]",
                                  with: "",
                                  options: .regularExpression)

        if let alias = embeddedForeignAliases(for: targetLanguage)[normalizedKey] {
            return alias
        }

        switch targetLanguage {
        case .traditionalChinese:
            if compactLatinToken.count == 1 || cleaned.range(of: #"^[A-Z0-9]{2,8}$"#, options: .regularExpression) != nil {
                return normalizedKey.map(String.init).joined(separator: " ")
            }
        case .japanese:
            if compactLatinToken.count == 1 || cleaned.range(of: #"^[A-Z0-9]{2,8}$"#, options: .regularExpression) != nil {
                return japaneseSpelling(for: normalizedKey)
            }
        case .english:
            return nil
        }

        return nil
    }

    private static func embeddedForeignAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return acronymAliases(for: .traditionalChinese)
        case .japanese:
            return acronymAliases(for: .japanese)
        case .english:
            return [:]
        }
    }

    private static func mergedAliases(_ groups: [String: String]...) -> [String: String] {
        groups.reduce(into: [:]) { merged, group in
            merged.merge(group) { _, new in
                new
            }
        }
    }

    private static func organizationPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "United Nations": "聯合國",
                "European Union": "歐盟",
                "International Space Station": "國際太空站",
                "World Health Organization": "世界衛生組織",
                "National Aeronautics and Space Administration": "美國太空總署",
                "Japan Aerospace Exploration Agency": "日本太空機構",
                "Public Broadcasting Service": "美國公共電視",
                "British Broadcasting Corporation": "英國廣播公司",
                "OpenAI": "OpenAI",
                "World Bank": "世界銀行",
                "World Food Programme": "世界糧食計畫署",
                "International Labour Organization": "國際勞工組織"
            ]
        case .japanese:
            return [
                "United Nations": "国連",
                "European Union": "ヨーロッパ連合",
                "International Space Station": "国際宇宙ステーション",
                "World Health Organization": "世界保健機関",
                "National Aeronautics and Space Administration": "ナサ",
                "Japan Aerospace Exploration Agency": "ジャクサ",
                "Public Broadcasting Service": "ピー ビー エス",
                "British Broadcasting Corporation": "ビー ビー シー",
                "OpenAI": "オープンエーアイ",
                "World Bank": "世界銀行",
                "World Food Programme": "世界食糧計画",
                "International Labour Organization": "国際労働機関"
            ]
        case .english:
            return [
                "聯合國": "United Nations",
                "联合国": "United Nations",
                "国連": "United Nations",
                "歐盟": "European Union",
                "欧盟": "European Union",
                "國際太空站": "International Space Station",
                "国際宇宙ステーション": "International Space Station",
                "世界衛生組織": "World Health Organization",
                "世界保健機関": "World Health Organization",
                "聯合國教科文組織": "UNESCO",
                "联合国教科文组织": "UNESCO",
                "聯合國兒童基金會": "UNICEF",
                "联合国儿童基金会": "UNICEF",
                "北大西洋公約組織": "NATO",
                "北大西洋条約機構": "NATO",
                "經濟合作暨發展組織": "OECD",
                "经济合作与发展组织": "OECD",
                "経済協力開発機構": "OECD",
                "世界貿易組織": "World Trade Organization",
                "世界贸易组织": "World Trade Organization",
                "世界貿易機関": "World Trade Organization",
                "國際貨幣基金": "International Monetary Fund",
                "国际货币基金": "International Monetary Fund",
                "国際通貨基金": "International Monetary Fund",
                "政府間氣候變化專門委員會": "Intergovernmental Panel on Climate Change",
                "政府间气候变化专门委员会": "Intergovernmental Panel on Climate Change",
                "気候変動に関する政府間パネル": "Intergovernmental Panel on Climate Change",
                "中央社": "CNA Taiwan",
                "公視": "PTS Taiwan",
                "公视": "PTS Taiwan",
                "日本放送協会": "NHK",
                "宇宙航空研究開発機構": "JAXA",
                "美國太空總署": "NASA",
                "美国太空总署": "NASA",
                "日本太空機構": "JAXA",
                "世界銀行": "World Bank",
                "世界银行": "World Bank",
                "世界食糧計画": "World Food Programme",
                "世界糧食計畫署": "World Food Programme",
                "國際勞工組織": "International Labour Organization",
                "国际劳工组织": "International Labour Organization",
                "国際労働機関": "International Labour Organization"
            ]
        }
    }

    private static func newsroomPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "Reuters": "路透社",
                "Associated Press": "美聯社",
                "Agence France-Presse": "法新社",
                "Bloomberg": "彭博",
                "The New York Times": "紐約時報",
                "New York Times": "紐約時報",
                "The Washington Post": "華盛頓郵報",
                "Washington Post": "華盛頓郵報",
                "Wall Street Journal": "華爾街日報",
                "Financial Times": "金融時報",
                "The Guardian": "衛報",
                "Guardian": "衛報",
                "Al Jazeera": "半島電視台",
                "Deutsche Welle": "德國之聲",
                "Voice of America": "美國之音",
                "PBS NewsHour": "美國公共電視新聞時段"
            ]
        case .japanese:
            return [
                "Reuters": "ロイター",
                "Associated Press": "AP通信",
                "Agence France-Presse": "AFP通信",
                "Bloomberg": "ブルームバーグ",
                "The New York Times": "ニューヨーク・タイムズ",
                "New York Times": "ニューヨーク・タイムズ",
                "The Washington Post": "ワシントン・ポスト",
                "Washington Post": "ワシントン・ポスト",
                "Wall Street Journal": "ウォール・ストリート・ジャーナル",
                "Financial Times": "フィナンシャル・タイムズ",
                "The Guardian": "ガーディアン",
                "Guardian": "ガーディアン",
                "Al Jazeera": "アルジャジーラ",
                "Deutsche Welle": "ドイチェ・ヴェレ",
                "Voice of America": "ボイス・オブ・アメリカ",
                "PBS NewsHour": "PBSニュースアワー"
            ]
        case .english:
            return [
                "路透社": "Reuters",
                "ロイター": "Reuters",
                "美聯社": "Associated Press",
                "美联社": "Associated Press",
                "AP通信": "Associated Press",
                "法新社": "Agence France-Presse",
                "AFP通信": "Agence France-Presse",
                "彭博": "Bloomberg",
                "ブルームバーグ": "Bloomberg",
                "紐約時報": "New York Times",
                "纽约时报": "New York Times",
                "ニューヨーク・タイムズ": "New York Times",
                "華盛頓郵報": "Washington Post",
                "华盛顿邮报": "Washington Post",
                "ワシントン・ポスト": "Washington Post",
                "華爾街日報": "Wall Street Journal",
                "华尔街日报": "Wall Street Journal",
                "ウォール・ストリート・ジャーナル": "Wall Street Journal",
                "金融時報": "Financial Times",
                "金融时报": "Financial Times",
                "フィナンシャル・タイムズ": "Financial Times",
                "衛報": "The Guardian",
                "卫报": "The Guardian",
                "ガーディアン": "The Guardian",
                "半島電視台": "Al Jazeera",
                "半岛电视台": "Al Jazeera",
                "アルジャジーラ": "Al Jazeera",
                "德國之聲": "Deutsche Welle",
                "德国之声": "Deutsche Welle",
                "ドイチェ・ヴェレ": "Deutsche Welle",
                "美國之音": "Voice of America",
                "美国之音": "Voice of America",
                "ボイス・オブ・アメリカ": "Voice of America"
            ]
        }
    }

    private static func brandPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "LEGO": "樂高",
                "Nintendo": "任天堂",
                "Samsung": "三星",
                "LINE": "Line",
                "ChatGPT": "ChatGPT",
                "Gemini": "Gemini",
                "Google Maps": "Google Maps",
                "Google Earth": "Google Earth",
                "YouTube Kids": "YouTube Kids",
                "Google Classroom": "Google Classroom"
            ]
        case .japanese:
            return [
                "Google": "グーグル",
                "YouTube": "ユーチューブ",
                "TikTok": "ティックトック",
                "Instagram": "インスタグラム",
                "Facebook": "フェイスブック",
                "WhatsApp": "ワッツアップ",
                "Telegram": "テレグラム",
                "ChatGPT": "チャットジーピーティー",
                "Gemini": "ジェミニ",
                "Microsoft": "マイクロソフト",
                "Apple": "アップル",
                "Amazon": "アマゾン",
                "Meta": "メタ",
                "Netflix": "ネットフリックス",
                "Spotify": "スポティファイ",
                "SpaceX": "スペースエックス",
                "Tesla": "テスラ",
                "Nintendo": "任天堂",
                "Sony": "ソニー",
                "Samsung": "サムスン",
                "LEGO": "レゴ",
                "Minecraft": "マインクラフト",
                "Roblox": "ロブロックス",
                "iPhone": "アイフォーン",
                "iPad": "アイパッド",
                "Android": "アンドロイド",
                "LINE": "ライン"
            ]
        case .english:
            return [
                "谷歌": "Google",
                "グーグル": "Google",
                "優兔": "YouTube",
                "ユーチューブ": "YouTube",
                "抖音": "TikTok",
                "ティックトック": "TikTok",
                "臉書": "Facebook",
                "脸书": "Facebook",
                "フェイスブック": "Facebook",
                "樂高": "LEGO",
                "乐高": "LEGO",
                "レゴ": "LEGO",
                "任天堂": "Nintendo",
                "三星": "Samsung",
                "メタ": "Meta",
                "微軟": "Microsoft",
                "微软": "Microsoft",
                "マイクロソフト": "Microsoft",
                "蘋果": "Apple",
                "苹果": "Apple",
                "アップル": "Apple",
                "亞馬遜": "Amazon",
                "亚马逊": "Amazon",
                "アマゾン": "Amazon"
            ]
        }
    }

    private static func sportsPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "Olympic Games": "奧林匹克運動會",
                "Paris Olympics": "巴黎奧運",
                "FIFA World Cup": "世界盃足球賽",
                "Wimbledon": "溫布頓網球錦標賽",
                "Super Bowl": "超級盃",
                "Formula 1": "一級方程式賽車",
                "Los Angeles Lakers": "洛杉磯湖人",
                "New York Yankees": "紐約洋基",
                "Golden State Warriors": "金州勇士",
                "Major League Baseball": "美國職棒大聯盟",
                "National Basketball Association": "美國職籃",
                "National Football League": "美式足球聯盟",
                "Shohei Ohtani": "大谷翔平"
            ]
        case .japanese:
            return [
                "Olympic Games": "オリンピック",
                "Paris Olympics": "パリ五輪",
                "FIFA World Cup": "サッカーワールドカップ",
                "Wimbledon": "ウィンブルドン",
                "Super Bowl": "スーパーボウル",
                "Formula 1": "フォーミュラワン",
                "Los Angeles Lakers": "ロサンゼルス・レイカーズ",
                "New York Yankees": "ニューヨーク・ヤンキース",
                "Golden State Warriors": "ゴールデンステート・ウォリアーズ",
                "Major League Baseball": "メジャーリーグベースボール",
                "National Basketball Association": "NBA",
                "National Football League": "NFL",
                "Shohei Ohtani": "大谷翔平"
            ]
        case .english:
            return [
                "奧林匹克運動會": "Olympic Games",
                "奥林匹克运动会": "Olympic Games",
                "オリンピック": "Olympic Games",
                "巴黎奧運": "Paris Olympics",
                "巴黎奥运": "Paris Olympics",
                "パリ五輪": "Paris Olympics",
                "世界盃足球賽": "FIFA World Cup",
                "世界杯足球赛": "FIFA World Cup",
                "サッカーワールドカップ": "FIFA World Cup",
                "溫布頓網球錦標賽": "Wimbledon",
                "温布尔登网球锦标赛": "Wimbledon",
                "ウィンブルドン": "Wimbledon",
                "超級盃": "Super Bowl",
                "超级碗": "Super Bowl",
                "スーパーボウル": "Super Bowl",
                "一級方程式賽車": "Formula 1",
                "一级方程式赛车": "Formula 1",
                "フォーミュラワン": "Formula 1",
                "洛杉磯湖人": "Los Angeles Lakers",
                "洛杉矶湖人": "Los Angeles Lakers",
                "ロサンゼルス・レイカーズ": "Los Angeles Lakers",
                "紐約洋基": "New York Yankees",
                "纽约洋基": "New York Yankees",
                "ニューヨーク・ヤンキース": "New York Yankees",
                "金州勇士": "Golden State Warriors",
                "ゴールデンステート・ウォリアーズ": "Golden State Warriors",
                "美國職棒大聯盟": "Major League Baseball",
                "美国职棒大联盟": "Major League Baseball",
                "メジャーリーグベースボール": "Major League Baseball",
                "美國職籃": "National Basketball Association",
                "美国职篮": "National Basketball Association",
                "美式足球聯盟": "National Football League",
                "美式足球联盟": "National Football League",
                "大谷翔平": "Shohei Ohtani"
            ]
        }
    }

    private static func technologyPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "Windows 11": "Windows 11",
                "Windows": "Windows",
                "macOS": "macOS",
                "iOS": "iOS",
                "iPadOS": "iPadOS",
                "Android": "Android",
                "ChromeOS": "ChromeOS",
                "Apple Watch": "Apple Watch",
                "AirPods": "AirPods",
                "Nintendo Switch": "Nintendo Switch",
                "PlayStation": "PlayStation",
                "Xbox": "Xbox",
                "MacBook": "MacBook",
                "Wi-Fi": "Wi-Fi",
                "Bluetooth": "Bluetooth",
                "USB-C": "USB-C"
            ]
        case .japanese:
            return [
                "Windows 11": "ウィンドウズ 11",
                "Windows": "ウィンドウズ",
                "macOS": "マックオーエス",
                "iOS": "アイオーエス",
                "iPadOS": "アイパッドオーエス",
                "Android": "アンドロイド",
                "ChromeOS": "クロームオーエス",
                "Apple Watch": "アップルウォッチ",
                "AirPods": "エアポッズ",
                "Nintendo Switch": "ニンテンドースイッチ",
                "PlayStation": "プレイステーション",
                "Xbox": "エックスボックス",
                "MacBook": "マックブック",
                "Wi-Fi": "ワイファイ",
                "Bluetooth": "ブルートゥース",
                "USB-C": "ユーエスビー シー"
            ]
        case .english:
            return [
                "任天堂 Switch": "Nintendo Switch",
                "ニンテンドースイッチ": "Nintendo Switch",
                "プレイステーション": "PlayStation",
                "エックスボックス": "Xbox",
                "アップルウォッチ": "Apple Watch",
                "エアポッズ": "AirPods",
                "視窗系統": "Windows",
                "ウィンドウズ": "Windows",
                "無線網路": "Wi-Fi",
                "藍牙": "Bluetooth",
                "蓝牙": "Bluetooth",
                "中央處理器": "CPU",
                "中央处理器": "CPU",
                "圖形處理器": "GPU",
                "图形处理器": "GPU",
                "記憶體": "RAM",
                "内存": "RAM"
            ]
        }
    }

    private static func geographyPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "United States": "美國",
                "Japan": "日本",
                "Taiwan": "台灣",
                "China": "中國",
                "Ukraine": "烏克蘭",
                "Russia": "俄羅斯",
                "Israel": "以色列",
                "Gaza": "加薩",
                "Germany": "德國",
                "France": "法國",
                "Canada": "加拿大",
                "Australia": "澳洲",
                "India": "印度",
                "Singapore": "新加坡",
                "Thailand": "泰國",
                "Vietnam": "越南",
                "Indonesia": "印尼",
                "Malaysia": "馬來西亞",
                "Philippines": "菲律賓",
                "South Korea": "南韓",
                "North Korea": "北韓",
                "Hong Kong": "香港",
                "Taipei": "台北",
                "Tokyo": "東京",
                "Beijing": "北京",
                "Seoul": "首爾",
                "New York": "紐約",
                "Los Angeles": "洛杉磯",
                "San Francisco": "舊金山",
                "London": "倫敦",
                "Paris": "巴黎",
                "Washington": "華盛頓",
                "Kyiv": "基輔",
                "California": "加州",
                "Silicon Valley": "矽谷",
                "Pacific Ocean": "太平洋",
                "Atlantic Ocean": "大西洋",
                "Arctic": "北極"
            ]
        case .japanese:
            return [
                "United States": "アメリカ",
                "Japan": "日本",
                "Taiwan": "台湾",
                "China": "中国",
                "Ukraine": "ウクライナ",
                "Russia": "ロシア",
                "Israel": "イスラエル",
                "Gaza": "ガザ",
                "Germany": "ドイツ",
                "France": "フランス",
                "Canada": "カナダ",
                "Australia": "オーストラリア",
                "India": "インド",
                "Singapore": "シンガポール",
                "Thailand": "タイ",
                "Vietnam": "ベトナム",
                "Indonesia": "インドネシア",
                "Malaysia": "マレーシア",
                "Philippines": "フィリピン",
                "South Korea": "韓国",
                "North Korea": "北朝鮮",
                "Hong Kong": "香港",
                "Taipei": "台北",
                "Tokyo": "東京",
                "Beijing": "北京",
                "Seoul": "ソウル",
                "New York": "ニューヨーク",
                "Los Angeles": "ロサンゼルス",
                "San Francisco": "サンフランシスコ",
                "London": "ロンドン",
                "Paris": "パリ",
                "Washington": "ワシントン",
                "Kyiv": "キーウ",
                "California": "カリフォルニア",
                "Silicon Valley": "シリコンバレー",
                "Pacific Ocean": "太平洋",
                "Atlantic Ocean": "大西洋",
                "Arctic": "北極"
            ]
        case .english:
            return [
                "台灣": "Taiwan",
                "台湾": "Taiwan",
                "美國": "United States",
                "美国": "United States",
                "アメリカ": "United States",
                "日本": "Japan",
                "中國": "China",
                "中国": "China",
                "烏克蘭": "Ukraine",
                "乌克兰": "Ukraine",
                "ウクライナ": "Ukraine",
                "俄羅斯": "Russia",
                "俄罗斯": "Russia",
                "ロシア": "Russia",
                "以色列": "Israel",
                "イスラエル": "Israel",
                "加薩": "Gaza",
                "加沙": "Gaza",
                "ガザ": "Gaza",
                "德國": "Germany",
                "德国": "Germany",
                "ドイツ": "Germany",
                "法國": "France",
                "法国": "France",
                "フランス": "France",
                "加拿大": "Canada",
                "カナダ": "Canada",
                "澳洲": "Australia",
                "澳大利亚": "Australia",
                "オーストラリア": "Australia",
                "印度": "India",
                "インド": "India",
                "新加坡": "Singapore",
                "シンガポール": "Singapore",
                "泰國": "Thailand",
                "泰国": "Thailand",
                "タイ": "Thailand",
                "越南": "Vietnam",
                "ベトナム": "Vietnam",
                "印尼": "Indonesia",
                "インドネシア": "Indonesia",
                "馬來西亞": "Malaysia",
                "马来西亚": "Malaysia",
                "マレーシア": "Malaysia",
                "菲律賓": "Philippines",
                "菲律宾": "Philippines",
                "フィリピン": "Philippines",
                "南韓": "South Korea",
                "南韩": "South Korea",
                "韓国": "South Korea",
                "北韓": "North Korea",
                "北韩": "North Korea",
                "北朝鮮": "North Korea",
                "香港": "Hong Kong",
                "台北": "Taipei",
                "臺北": "Taipei",
                "東京": "Tokyo",
                "东京": "Tokyo",
                "北京": "Beijing",
                "首爾": "Seoul",
                "首尔": "Seoul",
                "ソウル": "Seoul",
                "紐約": "New York",
                "纽约": "New York",
                "ニューヨーク": "New York",
                "洛杉磯": "Los Angeles",
                "洛杉矶": "Los Angeles",
                "ロサンゼルス": "Los Angeles",
                "舊金山": "San Francisco",
                "旧金山": "San Francisco",
                "サンフランシスコ": "San Francisco",
                "倫敦": "London",
                "伦敦": "London",
                "ロンドン": "London",
                "巴黎": "Paris",
                "パリ": "Paris",
                "華盛頓": "Washington",
                "华盛顿": "Washington",
                "ワシントン": "Washington",
                "基輔": "Kyiv",
                "基辅": "Kyiv",
                "キーウ": "Kyiv",
                "加州": "California",
                "カリフォルニア": "California",
                "矽谷": "Silicon Valley",
                "硅谷": "Silicon Valley",
                "シリコンバレー": "Silicon Valley",
                "太平洋": "Pacific Ocean",
                "大西洋": "Atlantic Ocean",
                "北極": "Arctic",
                "北极": "Arctic"
            ]
        }
    }

    private static func personPhraseAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "Donald Trump": "川普",
                "Joe Biden": "拜登",
                "Volodymyr Zelenskyy": "澤倫斯基",
                "Vladimir Putin": "普丁",
                "Elon Musk": "馬斯克",
                "Sam Altman": "山姆奧特曼",
                "Mark Zuckerberg": "祖克柏",
                "Sundar Pichai": "皮查伊",
                "Tim Cook": "庫克",
                "Jensen Huang": "黃仁勳",
                "Bill Gates": "比爾蓋茲"
            ]
        case .japanese:
            return [
                "Donald Trump": "トランプ氏",
                "Joe Biden": "バイデン大統領",
                "Volodymyr Zelenskyy": "ゼレンスキー大統領",
                "Vladimir Putin": "プーチン大統領",
                "Elon Musk": "イーロン・マスク",
                "Sam Altman": "サム・アルトマン",
                "Mark Zuckerberg": "マーク・ザッカーバーグ",
                "Sundar Pichai": "スンダー・ピチャイ",
                "Tim Cook": "ティム・クック",
                "Jensen Huang": "ジェンスン・フアン",
                "Bill Gates": "ビル・ゲイツ"
            ]
        case .english:
            return [
                "川普": "Donald Trump",
                "特朗普": "Donald Trump",
                "トランプ氏": "Donald Trump",
                "トランプ": "Donald Trump",
                "拜登": "Joe Biden",
                "バイデン大統領": "Joe Biden",
                "バイデン": "Joe Biden",
                "澤倫斯基": "Volodymyr Zelenskyy",
                "泽连斯基": "Volodymyr Zelenskyy",
                "ゼレンスキー大統領": "Volodymyr Zelenskyy",
                "ゼレンスキー": "Volodymyr Zelenskyy",
                "普丁": "Vladimir Putin",
                "普京": "Vladimir Putin",
                "プーチン大統領": "Vladimir Putin",
                "プーチン": "Vladimir Putin",
                "馬斯克": "Elon Musk",
                "马斯克": "Elon Musk",
                "イーロン・マスク": "Elon Musk",
                "山姆奧特曼": "Sam Altman",
                "山姆奥特曼": "Sam Altman",
                "サム・アルトマン": "Sam Altman",
                "祖克柏": "Mark Zuckerberg",
                "扎克伯格": "Mark Zuckerberg",
                "マーク・ザッカーバーグ": "Mark Zuckerberg",
                "皮查伊": "Sundar Pichai",
                "皮柴": "Sundar Pichai",
                "スンダー・ピチャイ": "Sundar Pichai",
                "庫克": "Tim Cook",
                "库克": "Tim Cook",
                "ティム・クック": "Tim Cook",
                "黃仁勳": "Jensen Huang",
                "黄仁勋": "Jensen Huang",
                "ジェンスン・フアン": "Jensen Huang",
                "比爾蓋茲": "Bill Gates",
                "比尔盖茨": "Bill Gates",
                "ビル・ゲイツ": "Bill Gates"
            ]
        }
    }

    private static func conceptPhraseAliasesForEnglish() -> [String: String] {
        [
            "人工智慧": "artificial intelligence",
            "人工知能": "artificial intelligence",
            "二氧化碳": "carbon dioxide",
            "二酸化炭素": "carbon dioxide"
        ]
    }

    private static func acronymAliases(for language: SourceContentLanguage) -> [String: String] {
        switch language {
        case .traditionalChinese:
            return [
                "AI": "人工智慧",
                "NASA": "美國太空總署",
                "JAXA": "日本太空機構",
                "BBC": "英國廣播公司",
                "PBS": "美國公共電視",
                "NHK": "日本放送協會",
                "WHO": "世界衛生組織",
                "UNESCO": "聯合國教科文組織",
                "UNICEF": "聯合國兒童基金會",
                "NATO": "北大西洋公約組織",
                "OECD": "經濟合作暨發展組織",
                "WTO": "世界貿易組織",
                "IMF": "國際貨幣基金",
                "IPCC": "政府間氣候變化專門委員會",
                "COP": "聯合國氣候會議",
                "G7": "七大工業國",
                "G20": "二十國集團",
                "ESA": "歐洲太空總署",
                "NOAA": "美國國家海洋暨大氣總署",
                "APEC": "亞太經濟合作會議",
                "ASEAN": "東南亞國協",
                "UNHCR": "聯合國難民署",
                "UNDP": "聯合國開發計畫署",
                "FAO": "聯合國糧農組織",
                "STEM": "科學科技工程與數學",
                "GDP": "國內生產毛額",
                "CNA": "中央社",
                "PTS": "公共電視",
                "UN": "聯合國",
                "EU": "歐盟",
                "US": "美國",
                "UK": "英國",
                "ISS": "國際太空站",
                "CO2": "二氧化碳",
                "OPENAI": "OpenAI",
                "CNN": "美國有線電視新聞網",
                "NPR": "美國國家公共廣播電台",
                "VOA": "美國之音",
                "DW": "德國之聲",
                "WMO": "世界氣象組織",
                "LINE": "Line",
                "MIT": "麻省理工學院",
                "UCLA": "加州大學洛杉磯分校",
                "NBA": "美國職籃",
                "MLB": "美國職棒大聯盟",
                "NFL": "美式足球聯盟",
                "FIFA": "國際足總",
                "IOC": "國際奧會",
                "CPU": "中央處理器",
                "GPU": "圖形處理器",
                "RAM": "記憶體"
            ]
        case .japanese:
            return [
                "AI": "エーアイ",
                "NASA": "ナサ",
                "JAXA": "ジャクサ",
                "BBC": "ビービーシー",
                "PBS": "ピービーエス",
                "NHK": "エヌエイチケー",
                "WHO": "世界保健機関",
                "UNESCO": "ユネスコ",
                "UNICEF": "ユニセフ",
                "NATO": "ナトー",
                "OECD": "経済協力開発機構",
                "WTO": "世界貿易機関",
                "IMF": "国際通貨基金",
                "IPCC": "気候変動に関する政府間パネル",
                "COP": "国連気候会議",
                "G7": "ジーセブン",
                "G20": "ジートゥエンティ",
                "ESA": "欧州宇宙機関",
                "NOAA": "アメリカ海洋大気庁",
                "APEC": "エーペック",
                "ASEAN": "アセアン",
                "UNHCR": "国連難民高等弁務官事務所",
                "UNDP": "国連開発計画",
                "FAO": "国連食糧農業機関",
                "STEM": "ステム",
                "GDP": "ジーディーピー",
                "CNA": "中央社",
                "PTS": "公共テレビ",
                "UN": "国連",
                "EU": "イーユー",
                "US": "アメリカ",
                "UK": "イギリス",
                "ISS": "国際宇宙ステーション",
                "CO2": "二酸化炭素",
                "OPENAI": "オープンエーアイ",
                "CNN": "シーエヌエヌ",
                "NPR": "エヌピーアール",
                "VOA": "ボイス・オブ・アメリカ",
                "DW": "ドイチェ・ヴェレ",
                "WMO": "世界気象機関",
                "LINE": "ライン",
                "MIT": "マサチューセッツ工科大学",
                "UCLA": "カリフォルニア大学ロサンゼルス校",
                "NBA": "エヌビーエー",
                "MLB": "メジャーリーグベースボール",
                "NFL": "エヌエフエル",
                "FIFA": "フィーファ",
                "IOC": "国際オリンピック委員会",
                "CPU": "シーピーユー",
                "GPU": "ジーピーユー",
                "RAM": "ラム"
            ]
        case .english:
            return [:]
        }
    }

    private static func japaneseSpelling(for token: String) -> String {
        token.map { character in
            switch character {
            case "A": return "エー"
            case "B": return "ビー"
            case "C": return "シー"
            case "D": return "ディー"
            case "E": return "イー"
            case "F": return "エフ"
            case "G": return "ジー"
            case "H": return "エイチ"
            case "I": return "アイ"
            case "J": return "ジェー"
            case "K": return "ケー"
            case "L": return "エル"
            case "M": return "エム"
            case "N": return "エヌ"
            case "O": return "オー"
            case "P": return "ピー"
            case "Q": return "キュー"
            case "R": return "アール"
            case "S": return "エス"
            case "T": return "ティー"
            case "U": return "ユー"
            case "V": return "ブイ"
            case "W": return "ダブリュー"
            case "X": return "エックス"
            case "Y": return "ワイ"
            case "Z": return "ゼット"
            case "0": return "ゼロ"
            case "1": return "いち"
            case "2": return "に"
            case "3": return "さん"
            case "4": return "よん"
            case "5": return "ご"
            case "6": return "ろく"
            case "7": return "なな"
            case "8": return "はち"
            case "9": return "きゅう"
            default: return String(character)
            }
        }
        .joined(separator: " ")
    }

    private static func sanitizeMonolingualFragment(
        _ text: String,
        language: SourceContentLanguage
    ) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "\\s+",
                                  with: " ",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.isEmpty == false else {
            return nil
        }

        let nonPunctuation = cleaned.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            scalar.properties.isAlphabetic ||
            scalar.properties.isIdeographic
        }

        return nonPunctuation ? cleaned : nil
    }

    private static func sanitizeEmbeddedEnglishFragment(_ text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "\\s+",
                                  with: " ",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.isEmpty == false else {
            return nil
        }

        let normalizedKey = cleaned
            .replacingOccurrences(of: ".", with: "")
            .uppercased()

        switch normalizedKey {
        case "AI":
            return "A I"
        case "BBC":
            return "B B C"
        case "PBS":
            return "P B S"
        case "NHK":
            return "N H K"
        case "UN":
            return "U N"
        case "US":
            return "U S"
        case "UK":
            return "U K"
        case "EU":
            return "E U"
        case "CO2":
            return "C O 2"
        default:
            break
        }

        if normalizedKey.range(of: #"^[A-Z0-9]{2,5}$"#, options: .regularExpression) != nil {
            return normalizedKey.map(String.init).joined(separator: " ")
        }

        return cleaned
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "/", with: " or ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func naturalLanguageSentences(in text: String, edition: AppEdition) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.setLanguage(naturalLanguage(for: edition))

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let candidate = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.isEmpty == false {
                sentences.append(candidate)
            }
            return true
        }

        return sentences
    }

    private static func naturalLanguage(for edition: AppEdition) -> NLLanguage {
        switch edition.contentLanguage {
        case .traditionalChinese:
            return .traditionalChinese
        case .japanese:
            return .japanese
        case .english:
            return .english
        }
    }
}

@MainActor
extension StoryNarrationController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        guard let highlight = localSpeechHighlightsByUtteranceID[utteranceID] else {
            return
        }

        activeHighlight = highlight
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        localSpeechHighlightsByUtteranceID.removeValue(forKey: utteranceID)
        if localSpeechUtteranceIDsInOrder.first == utteranceID {
            localSpeechUtteranceIDsInOrder.removeFirst()
        } else {
            localSpeechUtteranceIDsInOrder.removeAll { $0 == utteranceID }
        }

        if localSpeechUtteranceIDsInOrder.isEmpty {
            isStoppingLocalSpeech = false
            finishPlayback()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        localSpeechHighlightsByUtteranceID.removeValue(forKey: utteranceID)
        localSpeechUtteranceIDsInOrder.removeAll { $0 == utteranceID }

        guard synthesizer.isSpeaking == false else {
            return
        }

        let userInitiatedStop = isStoppingLocalSpeech
        isStoppingLocalSpeech = false

        guard userInitiatedStop == false else {
            return
        }

        if let requestID = activeStoryID {
            setFailure(.generationFailed, requestID: requestID)
        }
    }
}
