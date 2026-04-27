//
//  PremiumLibraryStore.swift
//  JuniorGlobe
//

import Foundation
import Combine

struct PremiumLibraryStore {
    private let baseURL: URL
    private struct WeeklyStoryRecord: Sendable {
        let story: CuratedStory
        let edition: AppEdition
        let ageBand: AgeBand
    }

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseURL = appSupportURL.appendingPathComponent("JuniorGlobe/PremiumLibrary", isDirectory: true)
        }
    }

    func archiveEntries(
        edition: AppEdition? = nil,
        ageBand: AgeBand? = nil
    ) -> [ArchivedFeedEntry] {
        load([ArchivedFeedEntry].self, from: archiveURL)
            .filter { entry in
                (edition == nil || entry.edition == edition) &&
                (ageBand == nil || entry.ageBand == ageBand)
            }
            .sorted { lhs, rhs in
                if lhs.dayKey != rhs.dayKey {
                    return lhs.dayKey > rhs.dayKey
                }

                if lhs.edition != rhs.edition {
                    return lhs.edition.rawValue < rhs.edition.rawValue
                }

                return lhs.ageBand.rawValue < rhs.ageBand.rawValue
            }
    }

    func archiveEntries(
        market: AudienceMarket,
        ageBand: AgeBand? = nil
    ) -> [ArchivedFeedEntry] {
        archiveEntries(edition: AppEdition.defaultEdition(for: market), ageBand: ageBand)
    }

    func saveArchiveEntry(_ entry: ArchivedFeedEntry, keepDays: Int) {
        var entries = archiveEntries(edition: nil, ageBand: nil)
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)

        let recentDayKeys = Array(
            Set(entries.map(\.dayKey))
                .sorted(by: >)
                .prefix(max(keepDays, 1))
        )

        let pruned = entries.filter { recentDayKeys.contains($0.dayKey) }
        save(pruned, to: archiveURL)
    }

    func storeCurrentFeed(
        edition: AppEdition,
        ageBand: AgeBand,
        policy: SubscriptionPolicy,
        snapshot: FeedSnapshot,
        trustedSources: [TrustedSource],
        deliveryMode: FeedDeliveryMode,
        lastUpdatedAt: Date?,
        dayKey: String?,
        savedAt: Date
    ) {
        guard policy.isPremium else {
            removeAllArchiveEntries()
            removeAllFavoriteRecords()
            return
        }

        guard
            policy.allowsOfflineArchive,
            policy.archiveDays > 0,
            let dayKey,
            snapshot.stories.isEmpty == false
        else {
            return
        }

        let archived = ArchivedFeedEntry(
            dayKey: dayKey,
            edition: edition,
            ageBand: ageBand,
            snapshot: snapshot,
            trustedSources: trustedSources,
            deliveryMode: deliveryMode,
            lastUpdatedAt: lastUpdatedAt,
            savedAt: savedAt
        )
        saveArchiveEntry(archived, keepDays: policy.archiveDays)
    }

    func removeAllArchiveEntries() {
        save([ArchivedFeedEntry](), to: archiveURL)
    }

    func favoriteRecords(edition: AppEdition? = nil) -> [FavoriteStoryRecord] {
        load([FavoriteStoryRecord].self, from: favoritesURL)
            .filter { record in
                edition == nil || record.edition == edition
            }
            .sorted { lhs, rhs in
                if lhs.savedAt != rhs.savedAt {
                    return lhs.savedAt > rhs.savedAt
                }

                return lhs.id < rhs.id
            }
    }

    func isFavorite(storyID: String, edition: AppEdition, ageBand: AgeBand) -> Bool {
        favoriteRecords(edition: edition).contains { record in
            record.story.id == storyID &&
            record.edition == edition &&
            record.ageBand == ageBand
        }
    }

    func isFavorite(storyID: String, market: AudienceMarket, ageBand: AgeBand) -> Bool {
        isFavorite(storyID: storyID, edition: .defaultEdition(for: market), ageBand: ageBand)
    }

    @discardableResult
    func toggleFavorite(story: CuratedStory, edition: AppEdition, ageBand: AgeBand, savedAt: Date) -> Bool {
        var records = favoriteRecords()
        let recordID = FavoriteStoryRecord(story: story, edition: edition, ageBand: ageBand, savedAt: savedAt).id

        if records.contains(where: { $0.id == recordID }) {
            records.removeAll { $0.id == recordID }
            save(records, to: favoritesURL)
            return false
        }

        records.append(FavoriteStoryRecord(story: story, edition: edition, ageBand: ageBand, savedAt: savedAt))
        save(records, to: favoritesURL)
        return true
    }

    @discardableResult
    func toggleFavorite(
        story: CuratedStory,
        edition: AppEdition,
        ageBand: AgeBand,
        savedAt: Date,
        allowed: Bool
    ) -> Bool {
        guard allowed else {
            return false
        }

        return toggleFavorite(story: story, edition: edition, ageBand: ageBand, savedAt: savedAt)
    }

    @discardableResult
    func toggleFavorite(story: CuratedStory, market: AudienceMarket, ageBand: AgeBand, savedAt: Date) -> Bool {
        toggleFavorite(
            story: story,
            edition: .defaultEdition(for: market),
            ageBand: ageBand,
            savedAt: savedAt
        )
    }

    func removeFavorite(recordID: String) {
        var records = favoriteRecords()
        records.removeAll { $0.id == recordID }
        save(records, to: favoritesURL)
    }

    func removeAllFavoriteRecords() {
        save([FavoriteStoryRecord](), to: favoritesURL)
    }

    func weeklyReport(referenceDate: Date = Date()) -> ParentWeeklyReport? {
        let entries = archiveEntries(edition: nil, ageBand: nil)
        guard entries.isEmpty == false else {
            return nil
        }

        let reportRange = weeklyReportRange(referenceDate: referenceDate)
        let weeklyEntries = entries.filter { entry in
            guard let entryDate = dayKeyDate(entry.dayKey) else {
                return false
            }
            return reportRange.contains(entryDate)
        }
        guard weeklyEntries.isEmpty == false else {
            return nil
        }

        let storyRecords = weeklyEntries.flatMap { entry in
            entry.snapshot.stories.map { story in
                WeeklyStoryRecord(
                    story: story,
                    edition: entry.edition,
                    ageBand: entry.ageBand
                )
            }
        }
        guard storyRecords.isEmpty == false else {
            return nil
        }

        let favoriteCount = favoriteRecords().filter { record in
            reportRange.contains(record.savedAt)
        }.count

        let regionCounts = countFrequencies(in: storyRecords.map { $0.story.region })
        let categoryCounts = countFrequencies(in: storyRecords.map { $0.story.category })
        let editionCounts = countFrequencies(in: storyRecords.map(\.edition))
        let ageBandCounts = countFrequencies(in: storyRecords.map(\.ageBand))
        let sourceCount = Set(storyRecords.map { $0.story.source.id }).count

        let topRegions = regionCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.sortOrder < rhs.key.sortOrder
            }
            .prefix(2)
            .map { $0.key }

        let topCategories = categoryCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .prefix(2)
            .map { $0.key }

        let storyCount = storyRecords.count
        let estimatedReadingMinutes = storyRecords.reduce(into: 0) { minutes, record in
            minutes += record.story.copy(for: record.ageBand).readingMinutes
        }
        let regionCount = regionCounts.count
        let categoryCount = categoryCounts.count
        let editionCount = editionCounts.count
        let ageBandCount = ageBandCounts.count
        let sortedDayKeys = Array(Set(weeklyEntries.map(\.dayKey))).sorted()
        let categoryDistribution = distributionSlices(
            from: categoryCounts,
            totalCount: storyCount
        ) { category, count, share in
            ParentWeeklyReportCategorySlice(category: category, storyCount: count, share: share)
        }
        let editionDistribution = distributionSlices(
            from: editionCounts,
            totalCount: storyCount
        ) { edition, count, share in
            ParentWeeklyReportEditionSlice(edition: edition, storyCount: count, share: share)
        }
        let ageBandDistribution = distributionSlices(
            from: ageBandCounts,
            totalCount: storyCount
        ) { ageBand, count, share in
            ParentWeeklyReportAgeBandSlice(ageBand: ageBand, storyCount: count, share: share)
        }

        return ParentWeeklyReport(
            startDayKey: sortedDayKeys.first,
            endDayKey: sortedDayKeys.last,
            daysCovered: sortedDayKeys.count,
            storyCount: storyCount,
            estimatedReadingMinutes: estimatedReadingMinutes,
            regionCount: regionCount,
            categoryCount: categoryCount,
            sourceCount: sourceCount,
            favoriteCount: favoriteCount,
            editionCount: editionCount,
            ageBandCount: ageBandCount,
            topRegions: topRegions,
            topCategories: topCategories,
            categoryDistribution: categoryDistribution,
            editionDistribution: editionDistribution,
            ageBandDistribution: ageBandDistribution,
            suggestedNextCategory: suggestedNextCategory(from: categoryCounts)
        )
    }

    private var archiveURL: URL {
        baseURL.appendingPathComponent("archive.json")
    }

    private var favoritesURL: URL {
        baseURL.appendingPathComponent("favorites.json")
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T {
        guard FileManager.default.fileExists(atPath: url.path) else {
            if let emptyArray = [] as? T {
                return emptyArray
            }

            fatalError("Unsupported default load type: \(T.self)")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(type, from: data)
        } catch {
            if let emptyArray = [] as? T {
                return emptyArray
            }

            fatalError("Unsupported load type after decoding failure: \(T.self)")
        }
    }

    private func countFrequencies<T: Hashable>(in values: [T]) -> [T: Int] {
        values.reduce(into: [:]) { counts, value in
            counts[value, default: 0] += 1
        }
    }

    private func weeklyReportRange(referenceDate: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? referenceDate
        return DateInterval(start: start, end: end)
    }

    private func dayKeyDate(_ dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }

    private func distributionSlices<Key: Hashable, Slice>(
        from counts: [Key: Int],
        totalCount: Int,
        build: (Key, Int, Double) -> Slice
    ) -> [Slice] {
        guard totalCount > 0 else {
            return []
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return String(describing: lhs.key) < String(describing: rhs.key)
            }
            .map { key, count in
                build(key, count, Double(count) / Double(totalCount))
            }
    }

    private func suggestedNextCategory(from counts: [StoryCategory: Int]) -> StoryCategory? {
        if let missingCategory = StoryCategory.allCases.first(where: { counts[$0] == nil }) {
            return missingCategory
        }

        return counts.min { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value < rhs.value
            }
            return lhs.key.rawValue < rhs.key.rawValue
        }?.key
    }
}

@MainActor
final class PremiumLibraryViewModel: ObservableObject {
    @Published private(set) var archiveEntries: [ArchivedFeedEntry] = []
    @Published private(set) var favoriteRecords: [FavoriteStoryRecord] = []
    @Published private(set) var weeklyReport: ParentWeeklyReport?

    private let store: PremiumLibraryStore
    private let now: () -> Date

    private var currentEdition: AppEdition = .taiwanZhHant
    private var currentAgeBand: AgeBand = .ages6to9
    private var currentPolicy = SubscriptionPolicy.current(isPremium: false, ageBand: .ages6to9)

    init(
        store: PremiumLibraryStore? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store ?? PremiumLibraryStore()
        self.now = now
        reload()
    }

    func syncCurrentFeed(
        edition: AppEdition,
        ageBand: AgeBand,
        policy: SubscriptionPolicy,
        snapshot: FeedSnapshot,
        trustedSources: [TrustedSource],
        deliveryMode: FeedDeliveryMode,
        lastUpdatedAt: Date?,
        dayKey: String?
    ) {
        currentEdition = edition
        currentAgeBand = ageBand
        currentPolicy = policy
        store.storeCurrentFeed(
            edition: edition,
            ageBand: ageBand,
            policy: policy,
            snapshot: snapshot,
            trustedSources: trustedSources,
            deliveryMode: deliveryMode,
            lastUpdatedAt: lastUpdatedAt,
            dayKey: dayKey,
            savedAt: now()
        )

        reload()
    }

    func isFavorite(_ story: CuratedStory, edition: AppEdition, ageBand: AgeBand) -> Bool {
        store.isFavorite(storyID: story.id, edition: edition, ageBand: ageBand)
    }

    func toggleFavorite(_ story: CuratedStory, edition: AppEdition, ageBand: AgeBand) {
        _ = store.toggleFavorite(
            story: story,
            edition: edition,
            ageBand: ageBand,
            savedAt: now(),
            allowed: currentPolicy.allowsFavorites
        )
        reload()
    }

    func removeFavorite(recordID: String) {
        guard currentPolicy.allowsFavorites else {
            reload()
            return
        }

        store.removeFavorite(recordID: recordID)
        reload()
    }

    func reload() {
        archiveEntries = currentPolicy.allowsOfflineArchive
            ? store.archiveEntries(edition: currentEdition, ageBand: currentAgeBand)
            : []
        favoriteRecords = currentPolicy.allowsFavorites ? store.favoriteRecords(edition: currentEdition) : []
        weeklyReport = currentPolicy.allowsParentWeeklyReport ? store.weeklyReport(referenceDate: now()) : nil
    }
}
