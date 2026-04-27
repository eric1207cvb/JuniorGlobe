//
//  NewsFeedViewModel.swift
//  JuniorGlobe
//

import Foundation
import Combine

@MainActor
final class NewsFeedViewModel: ObservableObject {
    @Published private(set) var snapshot: FeedSnapshot
    @Published private(set) var trustedSources: [TrustedSource]
    @Published private(set) var editorialPolicy: EditorialPolicy
    @Published private(set) var deliveryMode: FeedDeliveryMode = .unavailable
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var dayKey: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false

    private let liveService: LiveCuratedNewsService
    private var activeRequestID = UUID()

    init(liveService: LiveCuratedNewsService? = nil) {
        let resolvedLiveService = liveService ?? LiveCuratedNewsService()

        self.liveService = resolvedLiveService
        self.snapshot = .empty
        self.trustedSources = []
        self.editorialPolicy = resolvedLiveService.editorialPolicy
    }

    func load(
        edition: AppEdition,
        ageBand: AgeBand,
        includePremium: Bool,
        forceRefresh: Bool = false
    ) async {
        let requestID = UUID()
        activeRequestID = requestID

        if let cached = await liveService.cachedPresentation(
            for: edition,
            ageBand: ageBand,
            includePremium: includePremium
        ) {
            apply(cached, requestID: requestID)
        }

        if lastUpdatedAt == nil {
            isLoading = true
        } else {
            isRefreshing = true
        }

        let presentation = await liveService.refreshPresentation(
            for: edition,
            ageBand: ageBand,
            includePremium: includePremium,
            forceRefresh: forceRefresh
        )
        apply(presentation, requestID: requestID)

        isLoading = false
        isRefreshing = false
    }

    private func apply(_ presentation: NewsFeedPresentation, requestID: UUID) {
        guard activeRequestID == requestID else {
            return
        }

        snapshot = presentation.snapshot
        trustedSources = presentation.trustedSources
        editorialPolicy = liveService.editorialPolicy
        deliveryMode = presentation.deliveryMode
        lastUpdatedAt = presentation.lastUpdatedAt
        dayKey = presentation.dayKey
    }
}
