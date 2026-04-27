import XCTest
@testable import JuniorGlobe

@MainActor
final class PremiumLibraryStoreTests: XCTestCase {
    func testPremiumPolicyEnablesArchiveFavoritesAndWeeklyReport() {
        let policy = SubscriptionPolicy.current(isPremium: true, ageBand: .ages9to12)

        XCTAssertEqual(policy.visibleStoryLimit, 14)
        XCTAssertEqual(policy.archiveDays, 30)
        XCTAssertTrue(policy.allowsStoryNarration)
        XCTAssertTrue(policy.showsExpandedNarrationSegments)
        XCTAssertTrue(policy.showsExpandedStoryContent)
        XCTAssertTrue(policy.showsWhyItMatters)
        XCTAssertTrue(policy.showsBackgroundBrief)
        XCTAssertTrue(policy.showsThinkingPrompt)
        XCTAssertTrue(policy.usesPremiumRewriteStories)
        XCTAssertEqual(policy.premiumRewriteStoryCount, 4)
        XCTAssertTrue(policy.allowsFavorites)
        XCTAssertTrue(policy.allowsOfflineArchive)
        XCTAssertTrue(policy.allowsParentWeeklyReport)
    }

    func testFreePolicyKeepsBasicNarrationWithoutPremiumRewriteFeatures() {
        let policy = SubscriptionPolicy.current(isPremium: false, ageBand: .ages6to9)

        XCTAssertEqual(policy.visibleStoryLimit, 10)
        XCTAssertEqual(policy.archiveDays, 0)
        XCTAssertTrue(policy.allowsStoryNarration)
        XCTAssertFalse(policy.showsExpandedNarrationSegments)
        XCTAssertFalse(policy.showsExpandedStoryContent)
        XCTAssertFalse(policy.usesPremiumRewriteStories)
        XCTAssertEqual(policy.premiumRewriteStoryCount, 0)
        XCTAssertFalse(policy.allowsFavorites)
        XCTAssertFalse(policy.allowsOfflineArchive)
        XCTAssertFalse(policy.allowsParentWeeklyReport)
    }

    func testStoreKeepsOnlyThirtyRecentArchiveDays() {
        let store = makeStore(testName: #function)
        let source = DemoCuratedNewsService().trustedSources(for: .taiwan).first!
        let story = DemoCuratedNewsService().allStories.first!
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let baseDate = formatter.date(from: "2026-06-01")!

        for offset in 0..<32 {
            let date = calendar.date(byAdding: .day, value: -offset, to: baseDate)!
            let dayKey = formatter.string(from: date)
            let snapshot = FeedSnapshot(stories: [story], lockedStoryCount: 0, totalAvailableStoryCount: 1)
            let entry = ArchivedFeedEntry(
                dayKey: dayKey,
                market: .taiwan,
                ageBand: .ages9to12,
                snapshot: snapshot,
                trustedSources: [source],
                deliveryMode: .cached,
                lastUpdatedAt: nil,
                savedAt: Date()
            )
            store.saveArchiveEntry(entry, keepDays: 30)
        }

        let entries = store.archiveEntries(market: .taiwan, ageBand: .ages9to12)
        let dayKeys = Set(entries.map(\.dayKey))

        XCTAssertEqual(dayKeys.count, 30)
        XCTAssertTrue(dayKeys.contains("2026-06-01"))
        XCTAssertTrue(dayKeys.contains("2026-05-03"))
        XCTAssertFalse(dayKeys.contains("2026-05-02"))
    }

    func testStoreTogglesFavorites() {
        let store = makeStore(testName: #function)
        let story = DemoCuratedNewsService().allStories.first!

        let firstToggle = store.toggleFavorite(
            story: story,
            market: .taiwan,
            ageBand: .ages6to9,
            savedAt: Date()
        )
        XCTAssertTrue(firstToggle)
        XCTAssertEqual(store.favoriteRecords().count, 1)

        let secondToggle = store.toggleFavorite(
            story: story,
            market: .taiwan,
            ageBand: .ages6to9,
            savedAt: Date()
        )
        XCTAssertFalse(secondToggle)
        XCTAssertTrue(store.favoriteRecords().isEmpty)
    }

    func testFreeSyncDoesNotPersistArchiveOrFavorites() {
        let store = makeStore(testName: #function)
        let service = DemoCuratedNewsService()
        let story = service.allStories.first!
        let source = service.trustedSources(for: .taiwan).first!
        let now = makeUTCDate("2026-04-23")
        let snapshot = FeedSnapshot(stories: [story], lockedStoryCount: 0, totalAvailableStoryCount: 1)

        store.storeCurrentFeed(
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            policy: SubscriptionPolicy.current(isPremium: true, ageBand: .ages6to9),
            snapshot: snapshot,
            trustedSources: [source],
            deliveryMode: .live,
            lastUpdatedAt: now,
            dayKey: "2026-04-23",
            savedAt: now
        )
        _ = store.toggleFavorite(
            story: story,
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            savedAt: now,
            allowed: true
        )

        XCTAssertEqual(store.archiveEntries().count, 1)
        XCTAssertEqual(store.favoriteRecords().count, 1)

        store.storeCurrentFeed(
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            policy: SubscriptionPolicy.current(isPremium: false, ageBand: .ages6to9),
            snapshot: snapshot,
            trustedSources: [source],
            deliveryMode: .live,
            lastUpdatedAt: now,
            dayKey: "2026-04-23",
            savedAt: now
        )
        _ = store.toggleFavorite(
            story: story,
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            savedAt: now,
            allowed: false
        )

        XCTAssertTrue(store.archiveEntries().isEmpty)
        XCTAssertTrue(store.favoriteRecords().isEmpty)
    }

    func testFreeSyncNeverWritesArchiveEntries() {
        let store = makeStore(testName: #function)
        let service = DemoCuratedNewsService()
        let story = service.allStories.first!
        let source = service.trustedSources(for: .taiwan).first!
        let now = makeUTCDate("2026-04-23")
        let snapshot = FeedSnapshot(stories: [story], lockedStoryCount: 0, totalAvailableStoryCount: 1)

        store.storeCurrentFeed(
            edition: .taiwanZhHant,
            ageBand: .ages9to12,
            policy: SubscriptionPolicy.current(isPremium: false, ageBand: .ages9to12),
            snapshot: snapshot,
            trustedSources: [source],
            deliveryMode: .cached,
            lastUpdatedAt: now,
            dayKey: "2026-04-23",
            savedAt: now
        )

        XCTAssertTrue(store.archiveEntries().isEmpty)
    }

    func testWeeklyReportSummarizesRecentArchiveAndFavorites() {
        let store = makeStore(testName: #function)
        let service = DemoCuratedNewsService()
        let stories = Array(service.allStories.prefix(3))
        let trustedSources = service.trustedSources(for: .taiwan)
        let referenceDate = makeUTCDate("2026-04-23")

        for (index, dayKey) in ["2026-04-21", "2026-04-20", "2026-04-19"].enumerated() {
            let snapshot = FeedSnapshot(
                stories: Array(stories.prefix(index + 1)),
                lockedStoryCount: 0,
                totalAvailableStoryCount: index + 1
            )

            let entry = ArchivedFeedEntry(
                dayKey: dayKey,
                market: .taiwan,
                ageBand: .ages9to12,
                snapshot: snapshot,
                trustedSources: trustedSources,
                deliveryMode: .cached,
                lastUpdatedAt: nil,
                savedAt: referenceDate
            )
            store.saveArchiveEntry(entry, keepDays: 30)
        }

        _ = store.toggleFavorite(
            story: stories[0],
            market: .taiwan,
            ageBand: .ages9to12,
            savedAt: referenceDate
        )

        let report = store.weeklyReport(referenceDate: referenceDate)

        XCTAssertNotNil(report)
        XCTAssertEqual(report?.daysCovered, 3)
        XCTAssertEqual(report?.favoriteCount, 1)
        XCTAssertEqual(report?.storyCount, 6)
        XCTAssertGreaterThan(report?.estimatedReadingMinutes ?? 0, 0)
        XCTAssertGreaterThanOrEqual(report?.regionCount ?? 0, 1)
        XCTAssertGreaterThanOrEqual(report?.categoryCount ?? 0, 1)
        XCTAssertGreaterThanOrEqual(report?.sourceCount ?? 0, 1)
        XCTAssertEqual(report?.editionCount, 1)
        XCTAssertEqual(report?.ageBandCount, 1)
        XCTAssertEqual(report?.categoryDistribution.reduce(0) { $0 + $1.storyCount }, report?.storyCount)
        XCTAssertEqual(report?.editionDistribution.first?.edition, .taiwanZhHant)
        XCTAssertEqual(report?.ageBandDistribution.first?.ageBand, .ages9to12)
    }

    private func makeStore(testName: String) -> PremiumLibraryStore {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("JuniorGlobeTests/\(testName)", isDirectory: true)
        try? FileManager.default.removeItem(at: baseURL)
        return PremiumLibraryStore(baseURL: baseURL)
    }

    private func makeUTCDate(_ dayKey: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)!
    }
}
