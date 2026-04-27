//
//  PremiumLibraryDomain.swift
//  JuniorGlobe
//

import Foundation

struct SubscriptionPolicy: Sendable {
    let isPremium: Bool
    let visibleStoryLimit: Int
    let fullStoryLimit: Int
    let archiveDays: Int
    let allowsStoryNarration: Bool
    let showsExpandedNarrationSegments: Bool
    let showsExpandedStoryContent: Bool
    let showsWhyItMatters: Bool
    let showsBackgroundBrief: Bool
    let showsThinkingPrompt: Bool
    let usesPremiumRewriteStories: Bool
    let premiumRewriteStoryCount: Int
    let allowsFavorites: Bool
    let allowsOfflineArchive: Bool
    let allowsParentWeeklyReport: Bool

    static func current(isPremium: Bool, ageBand: AgeBand) -> SubscriptionPolicy {
        let freeStoryLimit: Int
        let premiumStoryLimit: Int

        switch ageBand {
        case .ages6to9:
            freeStoryLimit = 10
            premiumStoryLimit = 12
        case .ages9to12:
            freeStoryLimit = 10
            premiumStoryLimit = 14
        }

        return SubscriptionPolicy(
            isPremium: isPremium,
            visibleStoryLimit: isPremium ? premiumStoryLimit : freeStoryLimit,
            fullStoryLimit: premiumStoryLimit,
            archiveDays: isPremium ? 30 : 0,
            allowsStoryNarration: true,
            showsExpandedNarrationSegments: isPremium,
            showsExpandedStoryContent: isPremium,
            showsWhyItMatters: isPremium,
            showsBackgroundBrief: isPremium,
            showsThinkingPrompt: isPremium,
            usesPremiumRewriteStories: isPremium,
            premiumRewriteStoryCount: isPremium ? max(0, premiumStoryLimit - freeStoryLimit) : 0,
            allowsFavorites: isPremium,
            allowsOfflineArchive: isPremium,
            allowsParentWeeklyReport: isPremium
        )
    }
}

struct ArchivedFeedEntry: Codable, Identifiable, Sendable {
    let id: String
    let dayKey: String
    let edition: AppEdition
    let ageBand: AgeBand
    let snapshot: FeedSnapshot
    let trustedSources: [TrustedSource]
    let deliveryMode: FeedDeliveryMode
    let lastUpdatedAt: Date?
    let savedAt: Date

    var market: AudienceMarket {
        edition.market
    }

    init(
        dayKey: String,
        edition: AppEdition,
        ageBand: AgeBand,
        snapshot: FeedSnapshot,
        trustedSources: [TrustedSource],
        deliveryMode: FeedDeliveryMode,
        lastUpdatedAt: Date?,
        savedAt: Date
    ) {
        self.id = "\(dayKey)|\(edition.rawValue)|\(ageBand.rawValue)"
        self.dayKey = dayKey
        self.edition = edition
        self.ageBand = ageBand
        self.snapshot = snapshot
        self.trustedSources = trustedSources
        self.deliveryMode = deliveryMode
        self.lastUpdatedAt = lastUpdatedAt
        self.savedAt = savedAt
    }

    init(
        dayKey: String,
        market: AudienceMarket,
        ageBand: AgeBand,
        snapshot: FeedSnapshot,
        trustedSources: [TrustedSource],
        deliveryMode: FeedDeliveryMode,
        lastUpdatedAt: Date?,
        savedAt: Date
    ) {
        self.init(
            dayKey: dayKey,
            edition: .defaultEdition(for: market),
            ageBand: ageBand,
            snapshot: snapshot,
            trustedSources: trustedSources,
            deliveryMode: deliveryMode,
            lastUpdatedAt: lastUpdatedAt,
            savedAt: savedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case dayKey
        case edition
        case market
        case ageBand
        case snapshot
        case trustedSources
        case deliveryMode
        case lastUpdatedAt
        case savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        let decodedEdition = try container.decodeIfPresent(AppEdition.self, forKey: .edition)
        let decodedMarket = try container.decodeIfPresent(AudienceMarket.self, forKey: .market)
        edition = decodedEdition ?? AppEdition.defaultEdition(for: decodedMarket ?? .taiwan)
        ageBand = try container.decode(AgeBand.self, forKey: .ageBand)
        snapshot = try container.decode(FeedSnapshot.self, forKey: .snapshot)
        trustedSources = try container.decode([TrustedSource].self, forKey: .trustedSources)
        deliveryMode = try container.decode(FeedDeliveryMode.self, forKey: .deliveryMode)
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(dayKey)|\(edition.rawValue)|\(ageBand.rawValue)"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dayKey, forKey: .dayKey)
        try container.encode(edition, forKey: .edition)
        try container.encode(market, forKey: .market)
        try container.encode(ageBand, forKey: .ageBand)
        try container.encode(snapshot, forKey: .snapshot)
        try container.encode(trustedSources, forKey: .trustedSources)
        try container.encode(deliveryMode, forKey: .deliveryMode)
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(savedAt, forKey: .savedAt)
    }
}

struct FavoriteStoryRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let story: CuratedStory
    let edition: AppEdition
    let ageBand: AgeBand
    let savedAt: Date

    var market: AudienceMarket {
        edition.market
    }

    init(story: CuratedStory, edition: AppEdition, ageBand: AgeBand, savedAt: Date) {
        self.id = "\(story.id)|\(edition.rawValue)|\(ageBand.rawValue)"
        self.story = story
        self.edition = edition
        self.ageBand = ageBand
        self.savedAt = savedAt
    }

    init(story: CuratedStory, market: AudienceMarket, ageBand: AgeBand, savedAt: Date) {
        self.init(
            story: story,
            edition: .defaultEdition(for: market),
            ageBand: ageBand,
            savedAt: savedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case story
        case edition
        case market
        case ageBand
        case savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        story = try container.decode(CuratedStory.self, forKey: .story)
        let decodedEdition = try container.decodeIfPresent(AppEdition.self, forKey: .edition)
        let decodedMarket = try container.decodeIfPresent(AudienceMarket.self, forKey: .market)
        edition = decodedEdition ?? AppEdition.defaultEdition(for: decodedMarket ?? .taiwan)
        ageBand = try container.decode(AgeBand.self, forKey: .ageBand)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(story.id)|\(edition.rawValue)|\(ageBand.rawValue)"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(story, forKey: .story)
        try container.encode(edition, forKey: .edition)
        try container.encode(market, forKey: .market)
        try container.encode(ageBand, forKey: .ageBand)
        try container.encode(savedAt, forKey: .savedAt)
    }
}

struct ParentWeeklyReportCategorySlice: Identifiable, Hashable, Sendable {
    let category: StoryCategory
    let storyCount: Int
    let share: Double

    var id: String { category.rawValue }
}

struct ParentWeeklyReportEditionSlice: Identifiable, Hashable, Sendable {
    let edition: AppEdition
    let storyCount: Int
    let share: Double

    var id: String { edition.rawValue }
}

struct ParentWeeklyReportAgeBandSlice: Identifiable, Hashable, Sendable {
    let ageBand: AgeBand
    let storyCount: Int
    let share: Double

    var id: String { ageBand.rawValue }
}

struct ParentWeeklyReport: Sendable {
    let startDayKey: String?
    let endDayKey: String?
    let daysCovered: Int
    let storyCount: Int
    let estimatedReadingMinutes: Int
    let regionCount: Int
    let categoryCount: Int
    let sourceCount: Int
    let favoriteCount: Int
    let editionCount: Int
    let ageBandCount: Int
    let topRegions: [WorldRegion]
    let topCategories: [StoryCategory]
    let categoryDistribution: [ParentWeeklyReportCategorySlice]
    let editionDistribution: [ParentWeeklyReportEditionSlice]
    let ageBandDistribution: [ParentWeeklyReportAgeBandSlice]
    let suggestedNextCategory: StoryCategory?
}

extension ParentWeeklyReport {
    var dominantCategory: StoryCategory? {
        categoryDistribution.first?.category
    }

    var dominantEdition: AppEdition? {
        editionDistribution.first?.edition
    }

    var dominantAgeBand: AgeBand? {
        ageBandDistribution.first?.ageBand
    }
}
