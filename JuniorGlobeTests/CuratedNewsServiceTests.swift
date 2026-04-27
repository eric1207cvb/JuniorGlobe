import XCTest
@testable import JuniorGlobe

final class CuratedNewsServiceTests: XCTestCase {
    private let service = DemoCuratedNewsService()

    func testUnderstandingGuideAddsAgeAppropriateDepthAcrossEditions() {
        for edition in AppEdition.allCases {
            let youngerGuide = StoryMetadataClassifier.understandingGuide(
                for: .science,
                region: .global,
                ageBand: .ages6to9,
                edition: edition
            )
            let olderGuide = StoryMetadataClassifier.understandingGuide(
                for: .science,
                region: .global,
                ageBand: .ages9to12,
                edition: edition
            )

            XCTAssertFalse(youngerGuide.isEmpty, "Expected 6-9 guide for \(edition.rawValue)")
            XCTAssertFalse(olderGuide.isEmpty, "Expected 9-12 guide for \(edition.rawValue)")
            XCTAssertNotEqual(youngerGuide, olderGuide, "Guides should differ by age band for \(edition.rawValue)")
        }
    }

    func testReaderFacingTextSanitizerRemovesPromptLeakageAcrossLanguages() {
        let zhText = "請使用繁體中文並依照設定語言回答。孩子們今天在博物館學習海洋知識。"
        let jaText = "設定言語に合わせて日本語で書いてください。子どもたちは海の展示を学びました。"
        let enText = "Write in English and follow the system language. Children explored a museum exhibit about the ocean."

        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(zhText, language: .traditionalChinese),
            "孩子們今天在博物館學習海洋知識。"
        )
        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(jaText, language: .japanese),
            "子どもたちは海の展示を学びました。"
        )
        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(enText, language: .english),
            "Children explored a museum exhibit about the ocean."
        )
    }

    func testReaderFacingTextSanitizerCleansChineseNewswireArtifactsAndEnglishInsertions() {
        let text = "“[影]孩子在博物館學習 NASA 與 World Health Organization 的新計畫'''，也一起討論 AI 工具。”"

        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(text, language: .traditionalChinese),
            "孩子在博物館學習美國太空總署與世界衛生組織的新計畫，也一起討論人工智慧工具。"
        )
    }

    func testReaderFacingTextSanitizerPreloadsCommonChineseVocabularyAliases() {
        let text = "[圖]Students 在 museum 參加 climate change 與 renewable energy workshop，老師也介紹 satellite、robot 和 ocean 觀察。"

        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(text, language: .traditionalChinese),
            "學生在博物館參加氣候變遷與再生能源工作坊，老師也介紹衛星、機器人和海洋觀察。"
        )
    }

    func testReaderFacingTextSanitizerPreservesLongTermsWhileReplacingShorterAliases() {
        let text = "OpenAI 與 AI researchers 在 library 介紹 UNESCO、WMO 和 climate crisis，並帶孩子認識 Mars 與 Pacific Ocean。"

        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(text, language: .traditionalChinese),
            "OpenAI與人工智慧研究人員在圖書館介紹聯合國教科文組織、世界氣象組織和氣候危機，並帶孩子認識火星與太平洋。"
        )
    }

    func testReaderFacingTextSanitizerPreloadsInternationalOrganizationsAndEducationInstitutions() {
        let text = "學生在 elementary school 的 planetarium 活動中認識 World Bank、International Labour Organization、Harvard University 與 MIT，也看到 United Nations Educational, Scientific and Cultural Organization 的介紹。"

        XCTAssertEqual(
            ReaderFacingTextSanitizer.clean(text, language: .traditionalChinese),
            "學生在國小的天文館活動中認識世界銀行、國際勞工組織、哈佛大學與麻省理工學院，也看到聯合國教科文組織的介紹。"
        )
    }

    @MainActor
    func testPremiumRewriteStoriesAppendLocalizedFallbackCards() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_240)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("JuniorGlobeTests/\(#function)", isDirectory: true)
        try? FileManager.default.removeItem(at: baseURL)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let timestamp = Int(referenceDate.timeIntervalSince1970 * 1000)
        let cachedItemsJSON = (1...10).map { index in
            """
            {
              "category" : "science",
              "fetchedAt" : \(timestamp),
              "id" : "local-\(index)",
              "link" : "https://example.com/local-\(index)",
              "marketFocus" : [
                "taiwan"
              ],
              "publishedAt" : \(timestamp),
              "region" : "global",
              "safetyNotes" : [
                "safe"
              ],
              "source" : {
                "authorityLabel" : "國家通訊社",
                "countryLabel" : "台灣",
                "id" : "cna-live",
                "name" : "中央社",
                "preferredMarkets" : [
                  "taiwan"
                ],
                "reasonTrusted" : "trusted"
              },
              "summary" : "第\(index)則本地新聞讓孩子先掌握今天的世界重點。",
              "title" : "本地重點新聞 \(index)"
            }
            """
        }
        .joined(separator: ",")

        let cachedJSON = """
        {
          "dayKey" : "\(dayKey)",
          "items" : [
            \(cachedItemsJSON)
          ],
          "lastRefreshAt" : \(timestamp),
          "sourceRefreshDates" : {
          }
        }
        """
        try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

        PremiumRewriteURLProtocol.setPayload(
            """
            {
              "generatedAt": "2026-04-24T02:07:25.994Z",
              "source": {
                "cacheServed": true,
                "cacheUpdatedAt": "2026-04-24T01:53:04.288Z"
              },
              "stories": [
                {
                  "id": "remote-1",
                  "category": "science",
                  "region": "global",
                  "estimatedMinutes": 2,
                  "origin": {
                    "url": "https://www.abc.net.au/news/2026-04-24/science-story/1",
                    "publishedAt": "2026-04-24T01:00:00.000Z",
                    "sourceLabel": "ABC News Australia"
                  },
                  "localizations": {
                    "zh-TW": {
                      "headline": "Ocean teams share new ideas",
                      "deck": "孩子先知道海洋科學家如何一起解題。",
                      "question": "如果你是研究小隊的一員，你想先查哪個海域？",
                      "whyItMatters": "孩子可以從合作研究裡理解，世界各地會一起面對海洋問題。",
                      "sourceLabel": "ABC News Australia",
                      "versions": {
                        "ages6to8": {
                          "summary": "Ocean teams share new ideas。孩子先看海洋研究團隊怎麼合作。",
                          "highlights": [
                            "先看科學家怎麼分工合作。",
                            "再想這個研究會幫助哪些地方。"
                          ]
                        },
                        "ages11to12": {
                          "summary": "Ocean teams share new ideas。孩子可以進一步看不同國家的團隊怎麼共享資料。",
                          "highlights": [
                            "留意合作背後的資料交換與共同目標。"
                          ]
                        }
                      }
                    }
                  }
                },
                {
                  "id": "remote-2",
                  "category": "science",
                  "region": "global",
                  "estimatedMinutes": 2,
                  "origin": {
                    "url": "https://www.abc.net.au/news/2026-04-24/science-story/2",
                    "publishedAt": "2026-04-24T01:10:00.000Z",
                    "sourceLabel": "ABC News Australia"
                  },
                  "localizations": {
                    "zh-TW": {
                      "headline": "Sky watchers compare cloud maps",
                      "deck": "孩子先知道不同地方怎麼一起看雲圖。",
                      "question": "你覺得比對雲圖能先幫助哪些人？",
                      "whyItMatters": "孩子可以理解世界不同地方會一起觀察天氣，提早做準備。",
                      "sourceLabel": "ABC News Australia",
                      "versions": {
                        "ages6to8": {
                          "summary": "Sky watchers compare cloud maps。孩子先看大家怎麼一起分享天空觀察。",
                          "highlights": [
                            "先找出誰在分享觀察。",
                            "再想資料怎麼幫助更多人。"
                          ]
                        },
                        "ages11to12": {
                          "summary": "Sky watchers compare cloud maps。孩子可以進一步看不同地區怎麼共享天氣資訊。",
                          "highlights": [
                            "留意資料共享對學校與社區的影響。"
                          ]
                        }
                      }
                    }
                  }
                }
              ]
            }
            """
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PremiumRewriteURLProtocol.self]
        let session = URLSession(configuration: configuration)
        PremiumRewriteURLProtocol.resetLastRequest()
        let liveService = LiveCuratedNewsService(
            session: session,
            cacheStore: DailyNewsCacheStore(baseURL: baseURL),
            premiumRewriteBaseURL: URL(string: "https://rewrite.example.com"),
            premiumRewriteBearerToken: "test-premium-token",
            premiumRewriteClientID: "juniorglobe-tests",
            refreshInterval: 20 * 60,
            now: { referenceDate }
        )

        let presentation = await liveService.refreshPresentation(
            for: .taiwanZhHant,
            ageBand: .ages6to9,
            includePremium: true
        )

        XCTAssertEqual(presentation.snapshot.stories.count, 12)
        XCTAssertEqual(presentation.deliveryMode, .cached)

        let rewriteStories = Array(presentation.snapshot.stories.suffix(2))
        XCTAssertTrue(rewriteStories.allSatisfy(\.premiumOnly))
        XCTAssertTrue(rewriteStories.allSatisfy(\.isPremiumRewrite))
        XCTAssertEqual(rewriteStories.map { $0.copy(for: .ages6to9).headline }, ["全球科學整理", "全球科學整理"])
        XCTAssertEqual(
            rewriteStories.first?.copy(for: .ages6to9).summary,
            "孩子先看海洋研究團隊怎麼合作。"
        )
        XCTAssertTrue(
            presentation.trustedSources.contains { $0.id == "premium-rewrite-www-abc-net-au" }
        )
        XCTAssertEqual(PremiumRewriteURLProtocol.lastRequestValue(forHTTPHeaderField: "Authorization"), "Bearer test-premium-token")
        XCTAssertEqual(PremiumRewriteURLProtocol.lastRequestValue(forHTTPHeaderField: "X-JuniorGlobe-Entitlement"), "premium")
        XCTAssertEqual(PremiumRewriteURLProtocol.lastRequestValue(forHTTPHeaderField: "X-JuniorGlobe-Platform"), "ios")
        XCTAssertEqual(PremiumRewriteURLProtocol.lastRequestValue(forHTTPHeaderField: "X-JuniorGlobe-Client"), "juniorglobe-tests")
    }

    @MainActor
    func testPremiumRewriteIsDisabledWhenBearerTokenIsMissing() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_240)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("JuniorGlobeTests/\(#function)", isDirectory: true)
        try? FileManager.default.removeItem(at: baseURL)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let timestamp = Int(referenceDate.timeIntervalSince1970 * 1000)
        let cachedItemsJSON = (1...10).map { index in
            """
            {
              "category" : "science",
              "fetchedAt" : \(timestamp),
              "id" : "local-\(index)",
              "link" : "https://example.com/local-\(index)",
              "marketFocus" : [
                "taiwan"
              ],
              "publishedAt" : \(timestamp),
              "region" : "global",
              "safetyNotes" : [
                "safe"
              ],
              "source" : {
                "authorityLabel" : "國家通訊社",
                "countryLabel" : "台灣",
                "id" : "cna-live",
                "name" : "中央社",
                "preferredMarkets" : [
                  "taiwan"
                ],
                "reasonTrusted" : "trusted"
              },
              "summary" : "第\(index)則本地新聞讓孩子先掌握今天的世界重點。",
              "title" : "本地重點新聞 \(index)"
            }
            """
        }
        .joined(separator: ",")

        let cachedJSON = """
        {
          "dayKey" : "\(dayKey)",
          "items" : [
            \(cachedItemsJSON)
          ],
          "lastRefreshAt" : \(timestamp),
          "sourceRefreshDates" : {
          }
        }
        """
        try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PremiumRewriteURLProtocol.self]
        let session = URLSession(configuration: configuration)
        PremiumRewriteURLProtocol.resetLastRequest()
        let liveService = LiveCuratedNewsService(
            session: session,
            cacheStore: DailyNewsCacheStore(baseURL: baseURL),
            premiumRewriteBaseURL: URL(string: "https://rewrite.example.com"),
            premiumRewriteBearerToken: nil,
            premiumRewriteClientID: "juniorglobe-tests",
            refreshInterval: 20 * 60,
            now: { referenceDate }
        )

        let presentation = await liveService.refreshPresentation(
            for: .taiwanZhHant,
            ageBand: .ages6to9,
            includePremium: true
        )

        XCTAssertEqual(presentation.snapshot.stories.count, 10)
        XCTAssertEqual(PremiumRewriteURLProtocol.lastRequestURL(), nil)
    }

    func testNewsSafetyFilterAvoidsEnglishSubstringFalsePositives() {
        XCTAssertTrue(
            NewsSafetyFilter.isSafe(
                title: "NASA Wins Two Webby Awards",
                summary: "The team shared new science videos for students."
            )
        )
        XCTAssertTrue(
            NewsSafetyFilter.isSafe(
                title: "Water levels fall after a hot week",
                summary: "Students tracked the reservoir with teachers."
            )
        )
        XCTAssertTrue(
            NewsSafetyFilter.isSafe(
                title: "Warsh questioned on independence from Trump",
                summary: "The hearing focused on central bank policy."
            )
        )
        XCTAssertFalse(
            NewsSafetyFilter.isSafe(
                title: "Peace talks continue after war",
                summary: "Officials discussed the next steps."
            )
        )
    }

    func testPreferredStorySummaryDecodesHTMLArtifactsAndEntities() {
        let summary = LiveCuratedNewsService.preferredStorySummary(
            summary: "&lt;p&gt;Mars&#160;mission&amp;nbsp;update &amp;amp; crew &amp;#39;check-in&amp;#39;&lt;/p&gt;",
            fallbackTitle: "fallback"
        )

        XCTAssertEqual(summary, "Mars mission update & crew 'check-in'")
    }

    @MainActor
    func testLiveServiceFallsBackWhenCacheOnlyContainsOtherEditionLanguage() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_000)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("JuniorGlobeTests/\(#function)", isDirectory: true)
        try? FileManager.default.removeItem(at: baseURL)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let cachedJSON = """
        {
          "dayKey" : "\(dayKey)",
          "items" : [
            {
              "category" : "civics",
              "fetchedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "id" : "tw-only-story",
              "link" : "https://example.com/tw-only-story",
              "marketFocus" : [
                "taiwan"
              ],
              "publishedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "region" : "asiaPacific",
              "safetyNotes" : [
                "safe"
              ],
              "source" : {
                "authorityLabel" : "國家通訊社",
                "countryLabel" : "台灣",
                "id" : "cna-live",
                "name" : "中央社",
                "preferredMarkets" : [
                  "taiwan"
                ],
                "reasonTrusted" : "trusted"
              },
              "summary" : "這是一則只屬於繁中來源的快取新聞。",
              "title" : "台灣快取新聞"
            }
          ],
          "lastRefreshAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
          "sourceRefreshDates" : {
          }
        }
        """
        try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingNewsFeedURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let cacheStore = DailyNewsCacheStore(baseURL: baseURL)
        let liveService = LiveCuratedNewsService(
            session: session,
            cacheStore: cacheStore,
            refreshInterval: 20 * 60,
            now: { referenceDate }
        )

        let cachedPresentation = await liveService.cachedPresentation(
            for: .unitedStatesEn,
            ageBand: .ages6to9,
            includePremium: false
        )
        XCTAssertNil(cachedPresentation)

        let refreshedPresentation = await liveService.refreshPresentation(
            for: .unitedStatesEn,
            ageBand: .ages6to9,
            includePremium: false
        )

        let deliveryMode = refreshedPresentation.deliveryMode
        let stories = refreshedPresentation.snapshot.stories

        XCTAssertEqual(deliveryMode, .unavailable)
        XCTAssertTrue(stories.isEmpty)
        XCTAssertTrue(refreshedPresentation.trustedSources.allSatisfy { $0.isCompatible(with: .unitedStatesEn) })
    }

    @MainActor
    func testLiveServiceKeepsSparseEnglishCacheAsRealStoriesOnly() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_100)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("JuniorGlobeTests/\(#function)", isDirectory: true)
        try? FileManager.default.removeItem(at: baseURL)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let longEnglishSummary = """
        Children in several cities followed a new science project that compares cloud maps, wind reports, and changing temperatures so schools can decide how to adjust outdoor plans during unusual weather.
        """
        let cachedJSON = """
        {
          "dayKey" : "\(dayKey)",
          "items" : [
            {
              "category" : "science",
              "fetchedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "id" : "en-only-story",
              "link" : "https://example.com/en-only-story",
              "marketFocus" : [
                "unitedStates"
              ],
              "publishedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "region" : "northAmerica",
              "safetyNotes" : [
                "safe"
              ],
              "source" : {
                "authorityLabel" : "公共媒體",
                "countryLabel" : "英國",
                "id" : "bbc-live",
                "name" : "BBC News",
                "preferredMarkets" : [
                  "unitedStates"
                ],
                "reasonTrusted" : "trusted"
              },
              "summary" : "\(longEnglishSummary)",
              "title" : "English live cache story"
            }
          ],
          "lastRefreshAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
          "sourceRefreshDates" : {
          }
        }
        """
        try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

        let cacheStore = DailyNewsCacheStore(baseURL: baseURL)
        let liveService = LiveCuratedNewsService(
            session: URLSession(configuration: .ephemeral),
            cacheStore: cacheStore,
            refreshInterval: 20 * 60,
            now: { referenceDate }
        )

        guard let cachedPresentation = await liveService.cachedPresentation(
            for: .unitedStatesEn,
            ageBand: .ages6to9,
            includePremium: false
        ) else {
            return XCTFail("Expected cached presentation for US edition")
        }

        let stories = cachedPresentation.snapshot.stories
        XCTAssertEqual(stories.count, 1)
        XCTAssertTrue(stories.allSatisfy { $0.source.isCompatible(with: .unitedStatesEn) })
        XCTAssertTrue(stories.contains { $0.id == "en-only-story" })
        XCTAssertLessThanOrEqual(
            stories.first(where: { $0.id == "en-only-story" })?.copy(for: .ages6to9).summary.split(separator: " ").count ?? 0,
            26
        )
    }

    @MainActor
    func testLiveServiceRoutesStoriesByLanguageSpecificDifficultySignals() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_150)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)

        struct EditionFixture {
            let edition: AppEdition
            let sourceJSON: String
            let advancedTitle: String
            let advancedSummary: String
            let easyTitle: String
            let easySummary: String
            let cultureTitle: String
            let cultureSummary: String
        }

        let fixtures: [EditionFixture] = [
            EditionFixture(
                edition: .unitedStatesEn,
                sourceJSON: """
                {
                  "authorityLabel" : "Public Broadcaster",
                  "countryLabel" : "United Kingdom",
                  "id" : "bbc-live",
                  "name" : "BBC News",
                  "preferredMarkets" : [
                    "unitedStates"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                advancedTitle: "Senate reviews tariff budget plan",
                advancedSummary: "Lawmakers discussed inflation, tariffs, budget rules, and regulation changes for trade.",
                easyTitle: "Students map clouds for a school weather project",
                easySummary: "Children compared sky pictures and wind reports to plan safe outdoor play.",
                cultureTitle: "Library festival shares stories from many homes",
                cultureSummary: "Families brought music, snacks, and picture books to learn about different traditions."
            ),
            EditionFixture(
                edition: .taiwanZhHant,
                sourceJSON: """
                {
                  "authorityLabel" : "國家通訊社",
                  "countryLabel" : "台灣",
                  "id" : "cna-live",
                  "name" : "中央社",
                  "preferredMarkets" : [
                    "taiwan"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                advancedTitle: "國會討論關稅與預算方案",
                advancedSummary: "官員討論通膨、外交與監管政策如何影響產業和公共支出。",
                easyTitle: "學生用雲圖觀察校園天氣",
                easySummary: "孩子一起看天空和風向，決定操場活動怎麼更安全。",
                cultureTitle: "圖書館節分享不同家庭的故事",
                cultureSummary: "大家帶來音樂、點心和繪本，認識彼此的生活習慣。"
            ),
            EditionFixture(
                edition: .japanJa,
                sourceJSON: """
                {
                  "authorityLabel" : "公共媒體",
                  "countryLabel" : "日本",
                  "id" : "nhk-live",
                  "name" : "NHK NEWS WEB",
                  "preferredMarkets" : [
                    "japan"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                advancedTitle: "国会で関税と予算を協議",
                advancedSummary: "株価や外交、規制の影響について議論し、予算の配分を検討した。",
                easyTitle: "学校で雲を見て天気を調べる",
                easySummary: "子どもたちが空の写真と風のようすを比べて、安全な外遊びを考えた。",
                cultureTitle: "図書館まつりでいろいろな家の話を聞く",
                cultureSummary: "家族が音楽やおやつ、絵本を持ち寄って、ちがうくらし方を知った。"
            )
        ]

        func makeItemJSON(
            id: String,
            title: String,
            summary: String,
            category: String,
            region: String,
            market: String,
            sourceJSON: String
        ) -> String {
            """
            {
              "category" : "\(category)",
              "fetchedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "id" : "\(id)",
              "link" : "https://example.com/\(id)",
              "marketFocus" : [
                "\(market)"
              ],
              "publishedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "region" : "\(region)",
              "safetyNotes" : [
                "safe"
              ],
              "source" : \(sourceJSON),
              "summary" : "\(summary)",
              "title" : "\(title)"
            }
            """
        }

        for fixture in fixtures {
            let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("JuniorGlobeTests/\(#function)/\(fixture.edition.rawValue)", isDirectory: true)
            try? FileManager.default.removeItem(at: baseURL)
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let cachedJSON = """
            {
              "dayKey" : "\(dayKey)",
              "items" : [
                \(makeItemJSON(
                    id: "\(fixture.edition.rawValue)-advanced",
                    title: fixture.advancedTitle,
                    summary: fixture.advancedSummary,
                    category: "civics",
                    region: "global",
                    market: fixture.edition.market.rawValue,
                    sourceJSON: fixture.sourceJSON
                )),
                \(makeItemJSON(
                    id: "\(fixture.edition.rawValue)-science",
                    title: fixture.easyTitle,
                    summary: fixture.easySummary,
                    category: "science",
                    region: "global",
                    market: fixture.edition.market.rawValue,
                    sourceJSON: fixture.sourceJSON
                )),
                \(makeItemJSON(
                    id: "\(fixture.edition.rawValue)-culture",
                    title: fixture.cultureTitle,
                    summary: fixture.cultureSummary,
                    category: "culture",
                    region: "global",
                    market: fixture.edition.market.rawValue,
                    sourceJSON: fixture.sourceJSON
                ))
              ],
              "lastRefreshAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "sourceRefreshDates" : {
              }
            }
            """
            try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

            let liveService = LiveCuratedNewsService(
                session: URLSession(configuration: .ephemeral),
                cacheStore: DailyNewsCacheStore(baseURL: baseURL),
                refreshInterval: 20 * 60,
                now: { referenceDate }
            )

            guard let youngerPresentation = await liveService.cachedPresentation(
                for: fixture.edition,
                ageBand: .ages6to9,
                includePremium: false
            ) else {
                return XCTFail("Expected younger presentation for \(fixture.edition.rawValue)")
            }

            guard let olderPresentation = await liveService.cachedPresentation(
                for: fixture.edition,
                ageBand: .ages9to12,
                includePremium: false
            ) else {
                return XCTFail("Expected older presentation for \(fixture.edition.rawValue)")
            }

            let youngerIDs = Set(youngerPresentation.snapshot.stories.map(\.id))
            let olderIDs = Set(olderPresentation.snapshot.stories.map(\.id))
            let advancedID = "\(fixture.edition.rawValue)-advanced"

            XCTAssertFalse(
                youngerIDs.contains(advancedID),
                "6-9 feed should exclude advanced \(fixture.edition.rawValue) story"
            )
            XCTAssertTrue(
                olderIDs.contains(advancedID),
                "9-12 feed should include advanced \(fixture.edition.rawValue) story"
            )
            XCTAssertGreaterThanOrEqual(olderIDs.count, youngerIDs.count)
        }
    }

    @MainActor
    func testYoungerEditionsKeepSafeContextualStoriesWhenGentlePoolIsThin() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_175)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)

        struct Fixture {
            let edition: AppEdition
            let sourceJSON: String
            let firstTitle: String
            let firstSummary: String
            let firstRegion: String
            let secondTitle: String
            let secondSummary: String
            let secondRegion: String
        }

        let fixtures: [Fixture] = [
            Fixture(
                edition: .unitedStatesEn,
                sourceJSON: """
                {
                  "authorityLabel" : "Public Broadcaster",
                  "countryLabel" : "United States",
                  "id" : "pbs-live",
                  "name" : "PBS NewsHour",
                  "preferredMarkets" : [
                    "unitedStates"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                firstTitle: "City helpers plan easier routes to the library",
                firstSummary: "Teachers, bus drivers, and park staff listened to families and planned easier routes so children can reach the library, playground, and after-school clubs more safely each week together.",
                firstRegion: "northAmerica",
                secondTitle: "Neighborhood teams add calm signs near school corners",
                secondSummary: "Community volunteers and school workers studied busy corners, shared notes about walking times, and agreed on new signs so younger students can notice turns and cross more carefully after class.",
                secondRegion: "global"
            ),
            Fixture(
                edition: .japanJa,
                sourceJSON: """
                {
                  "authorityLabel" : "公共媒體",
                  "countryLabel" : "日本",
                  "id" : "nhk-live",
                  "name" : "NHK NEWS WEB",
                  "preferredMarkets" : [
                    "japan"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                firstTitle: "町の人と学校が新しい帰り道を考える",
                firstSummary: "子どもたちが図書館や公園に行きやすくなるように、学校と町の人が道やバスの使い方をゆっくり話し合い、みんなの困りごとを集めて新しい帰り方を考えた。",
                firstRegion: "asiaPacific",
                secondTitle: "学校の近くに見やすい案内を増やす",
                secondSummary: "地域の大人と先生が交差点のようすを見ながら、低学年でも曲がる場所がわかりやすくなるように、やさしい言葉の案内板を置く計画をまとめた。",
                secondRegion: "global"
            )
        ]

        func makeItemJSON(
            id: String,
            title: String,
            summary: String,
            region: String,
            market: String,
            sourceJSON: String
        ) -> String {
            """
            {
              "category" : "civics",
              "fetchedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "id" : "\(id)",
              "link" : "https://example.com/\(id)",
              "marketFocus" : [
                "\(market)"
              ],
              "publishedAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "region" : "\(region)",
              "safetyNotes" : [
                "safe"
              ],
              "source" : \(sourceJSON),
              "summary" : "\(summary)",
              "title" : "\(title)"
            }
            """
        }

        for fixture in fixtures {
            let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("JuniorGlobeTests/\(#function)/\(fixture.edition.rawValue)", isDirectory: true)
            try? FileManager.default.removeItem(at: baseURL)
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let cachedJSON = """
            {
              "dayKey" : "\(dayKey)",
              "items" : [
                \(makeItemJSON(
                    id: "\(fixture.edition.rawValue)-contextual-1",
                    title: fixture.firstTitle,
                    summary: fixture.firstSummary,
                    region: fixture.firstRegion,
                    market: fixture.edition.market.rawValue,
                    sourceJSON: fixture.sourceJSON
                )),
                \(makeItemJSON(
                    id: "\(fixture.edition.rawValue)-contextual-2",
                    title: fixture.secondTitle,
                    summary: fixture.secondSummary,
                    region: fixture.secondRegion,
                    market: fixture.edition.market.rawValue,
                    sourceJSON: fixture.sourceJSON
                ))
              ],
              "lastRefreshAt" : \(Int(referenceDate.timeIntervalSince1970 * 1000)),
              "sourceRefreshDates" : {
              }
            }
            """
            try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

            let liveService = LiveCuratedNewsService(
                session: URLSession(configuration: .ephemeral),
                cacheStore: DailyNewsCacheStore(baseURL: baseURL),
                refreshInterval: 20 * 60,
                now: { referenceDate }
            )

            guard let youngerPresentation = await liveService.cachedPresentation(
                for: fixture.edition,
                ageBand: .ages6to9,
                includePremium: false
            ) else {
                return XCTFail("Expected younger contextual presentation for \(fixture.edition.rawValue)")
            }

            XCTAssertEqual(
                youngerPresentation.snapshot.stories.count,
                2,
                "6-9 feed should keep safe contextual stories for \(fixture.edition.rawValue)"
            )
        }
    }

    @MainActor
    func testLiveServiceRefreshesSparseFreshCachesWhenCoverageIsTooLow() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_190)
        let dayKey = NewsCacheDayBucket.dayKey(for: referenceDate)

        struct Fixture {
            let edition: AppEdition
            let ageBand: AgeBand
            let sourceJSON: String
            let seedID: String
            let seedTitle: String
            let seedSummary: String
            let feedSourceIDs: [String]
            let expectedURLs: Set<String>
            let minimumStoryCount: Int
        }

        let fixtures: [Fixture] = [
            Fixture(
                edition: .unitedStatesEn,
                ageBand: .ages9to12,
                sourceJSON: """
                {
                  "authorityLabel" : "Public Broadcaster",
                  "countryLabel" : "United Kingdom",
                  "id" : "bbc-live",
                  "name" : "BBC News",
                  "preferredMarkets" : [
                    "unitedStates"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                seedID: "us-seed-story",
                seedTitle: "One calm science story",
                seedSummary: "Students compare sky maps and simple weather notes together.",
                feedSourceIDs: [
                    "bbc-world",
                    "bbc-technology",
                    "bbc-science",
                    "pbs-headlines",
                    "nasa-latest",
                    "nasa-technology",
                    "jpl-news"
                ],
                expectedURLs: Set([
                    "https://feeds.bbci.co.uk/news/world/rss.xml",
                    "https://feeds.bbci.co.uk/news/technology/rss.xml",
                    "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml",
                    "https://www.pbs.org/newshour/feeds/rss/headlines",
                    "https://www.nasa.gov/feed/",
                    "https://www.nasa.gov/technology/feed/",
                    "https://www.jpl.nasa.gov/feeds/news/"
                ]),
                minimumStoryCount: 4
            ),
            Fixture(
                edition: .japanJa,
                ageBand: .ages6to9,
                sourceJSON: """
                {
                  "authorityLabel" : "公共媒體",
                  "countryLabel" : "日本",
                  "id" : "nhk-live",
                  "name" : "NHK NEWS WEB",
                  "preferredMarkets" : [
                    "japan"
                  ],
                  "reasonTrusted" : "trusted"
                }
                """,
                seedID: "jp-seed-story",
                seedTitle: "ひとつだけのニュース",
                seedSummary: "子どもが空を見ながら天気をしらべた。",
                feedSourceIDs: [
                    "nhk-general",
                    "nhk-science-medical",
                    "nhk-economy",
                    "nhk-international"
                ],
                expectedURLs: Set([
                    "https://www3.nhk.or.jp/rss/news/cat0.xml",
                    "https://www3.nhk.or.jp/rss/news/cat3.xml",
                    "https://www3.nhk.or.jp/rss/news/cat5.xml",
                    "https://www3.nhk.or.jp/rss/news/cat6.xml"
                ]),
                minimumStoryCount: 4
            )
        ]

        func sourceRefreshDatesJSON(for sourceIDs: [String], timestamp: Int) -> String {
            sourceIDs
                .map { "\"\($0)\" : \(timestamp)" }
                .joined(separator: ",")
        }

        for fixture in fixtures {
            RecordingNewsFeedURLProtocol.reset()

            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RecordingNewsFeedURLProtocol.self]
            let session = URLSession(configuration: configuration)

            let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("JuniorGlobeTests/\(#function)/\(fixture.edition.rawValue)", isDirectory: true)
            try? FileManager.default.removeItem(at: baseURL)
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let timestamp = Int(referenceDate.timeIntervalSince1970 * 1000)
            let cachedJSON = """
            {
              "dayKey" : "\(dayKey)",
              "items" : [
                {
                  "category" : "science",
                  "fetchedAt" : \(timestamp),
                  "id" : "\(fixture.seedID)",
                  "link" : "https://example.com/\(fixture.seedID)",
                  "marketFocus" : [
                    "\(fixture.edition.market.rawValue)"
                  ],
                  "publishedAt" : \(timestamp),
                  "region" : "global",
                  "safetyNotes" : [
                    "safe"
                  ],
                  "source" : \(fixture.sourceJSON),
                  "summary" : "\(fixture.seedSummary)",
                  "title" : "\(fixture.seedTitle)"
                }
              ],
              "lastRefreshAt" : \(timestamp),
              "sourceRefreshDates" : {
                \(sourceRefreshDatesJSON(for: fixture.feedSourceIDs, timestamp: timestamp))
              }
            }
            """
            try cachedJSON.data(using: .utf8)?.write(to: baseURL.appendingPathComponent("\(dayKey).json"))

            let liveService = LiveCuratedNewsService(
                session: session,
                cacheStore: DailyNewsCacheStore(baseURL: baseURL),
                refreshInterval: 20 * 60,
                now: { referenceDate }
            )

            let presentation = await liveService.refreshPresentation(
                for: fixture.edition,
                ageBand: fixture.ageBand,
                includePremium: false
            )

            XCTAssertEqual(presentation.deliveryMode, .live)
            XCTAssertGreaterThanOrEqual(
                presentation.snapshot.stories.count,
                fixture.minimumStoryCount,
                "Expected sparse \(fixture.edition.rawValue) cache to refill with live stories"
            )
            XCTAssertEqual(Set(RecordingNewsFeedURLProtocol.snapshot()), fixture.expectedURLs)
        }
    }

    @MainActor
    func testLiveServiceRequestsExpandedOfficialFeedsForEachEdition() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_776_720_200)

        func requestedFeedURLs(for edition: AppEdition) async -> (Set<String>, NewsFeedPresentation) {
            RecordingNewsFeedURLProtocol.reset()

            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RecordingNewsFeedURLProtocol.self]
            let session = URLSession(configuration: configuration)

            let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("JuniorGlobeTests/\(#function)/\(edition.rawValue)", isDirectory: true)
            try? FileManager.default.removeItem(at: baseURL)

            let liveService = LiveCuratedNewsService(
                session: session,
                cacheStore: DailyNewsCacheStore(baseURL: baseURL),
                refreshInterval: 20 * 60,
                now: { referenceDate }
            )

            let presentation = await liveService.refreshPresentation(
                for: edition,
                ageBand: .ages6to9,
                includePremium: false,
                forceRefresh: true
            )

            return (Set(RecordingNewsFeedURLProtocol.snapshot()), presentation)
        }

        let (taiwanURLs, taiwanPresentation) = await requestedFeedURLs(for: .taiwanZhHant)
        XCTAssertEqual(
            taiwanURLs,
            Set([
                "https://feeds.feedburner.com/rsscna/intworld",
                "https://feeds.feedburner.com/rsscna/technology",
                "https://feeds.feedburner.com/rsscna/culture",
                "https://feeds.feedburner.com/rsscna/lifehealth",
                "https://news.pts.org.tw/xml/newsfeed.xml"
            ])
        )
        XCTAssertEqual(Set(taiwanPresentation.trustedSources.map(\.id)), Set(["cna-live", "pts-live"]))
        XCTAssertEqual(taiwanPresentation.snapshot.stories.count, 5)

        let (japanURLs, japanPresentation) = await requestedFeedURLs(for: .japanJa)
        XCTAssertEqual(
            japanURLs,
            Set([
                "https://www3.nhk.or.jp/rss/news/cat0.xml",
                "https://www3.nhk.or.jp/rss/news/cat3.xml",
                "https://www3.nhk.or.jp/rss/news/cat5.xml",
                "https://www3.nhk.or.jp/rss/news/cat6.xml"
            ])
        )
        XCTAssertEqual(Set(japanPresentation.trustedSources.map(\.id)), Set(["nhk-live"]))
        XCTAssertEqual(japanPresentation.snapshot.stories.count, 4)

        let (usURLs, usPresentation) = await requestedFeedURLs(for: .unitedStatesEn)
        XCTAssertEqual(
            usURLs,
            Set([
                "https://feeds.bbci.co.uk/news/world/rss.xml",
                "https://feeds.bbci.co.uk/news/technology/rss.xml",
                "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml",
                "https://www.pbs.org/newshour/feeds/rss/headlines",
                "https://www.nasa.gov/feed/",
                "https://www.nasa.gov/technology/feed/",
                "https://www.jpl.nasa.gov/feeds/news/"
            ])
        )
        XCTAssertEqual(Set(usPresentation.trustedSources.map(\.id)), Set(["bbc-live", "pbs-live", "nasa-live", "jpl-live"]))
        XCTAssertEqual(usPresentation.snapshot.stories.count, 7)
    }

    func testFreeFeedExcludesPremiumStories() {
        let snapshot = service.feed(for: .taiwan, ageBand: .ages6to9, includePremium: false)

        XCTAssertEqual(snapshot.stories.count, 10)
        XCTAssertTrue(snapshot.stories.allSatisfy { $0.premiumOnly == false })
        XCTAssertGreaterThan(snapshot.lockedStoryCount, 0)
    }

    func testPremiumFeedKeepsWorldCoverageDiverse() {
        let snapshot = service.feed(for: .unitedStates, ageBand: .ages9to12, includePremium: true)

        XCTAssertEqual(snapshot.stories.count, 14)
        XCTAssertGreaterThanOrEqual(snapshot.visibleRegionCount, 5)
        XCTAssertGreaterThanOrEqual(snapshot.visibleSourceCount, 5)
    }

    func testExpandedFreeFeedKeepsTenStoriesAcrossAgeBands() {
        let youngerSnapshot = service.feed(for: .taiwan, ageBand: .ages6to9, includePremium: false)
        let olderSnapshot = service.feed(for: .taiwan, ageBand: .ages9to12, includePremium: false)

        XCTAssertEqual(youngerSnapshot.stories.count, 10)
        XCTAssertEqual(olderSnapshot.stories.count, 10)
        XCTAssertGreaterThanOrEqual(olderSnapshot.visibleRegionCount, youngerSnapshot.visibleRegionCount)
    }

    func testEveryStoryContainsTwoAgeBands() {
        XCTAssertFalse(service.allStories.isEmpty)

        for story in service.allStories {
            XCTAssertNotNil(story.ageCopies[.ages6to9], "Missing 6-9 copy for \(story.id)")
            XCTAssertNotNil(story.ageCopies[.ages9to12], "Missing 9-12 copy for \(story.id)")
        }
    }

    func testEditionFeedsOnlyUseMatchingLanguageSources() {
        for edition in AppEdition.allCases {
            let sampleStories = service.sampleStories(for: edition)
            XCTAssertFalse(sampleStories.isEmpty, "Expected sample stories for \(edition.rawValue)")
            XCTAssertTrue(
                sampleStories.allSatisfy { $0.source.isCompatible(with: edition) },
                "Found incompatible sample story source for \(edition.rawValue)"
            )

            let trustedSources = service.trustedSources(for: edition)
            XCTAssertFalse(trustedSources.isEmpty, "Expected trusted sources for \(edition.rawValue)")
            XCTAssertTrue(
                trustedSources.allSatisfy { $0.isCompatible(with: edition) },
                "Found incompatible trusted source for \(edition.rawValue)"
            )

            let snapshot = service.feed(for: edition, ageBand: .ages9to12, includePremium: true)
            XCTAssertTrue(
                snapshot.stories.allSatisfy { $0.source.isCompatible(with: edition) },
                "Feed for \(edition.rawValue) included mismatched source language"
            )

            let freeSnapshot = service.feed(for: edition, ageBand: .ages6to9, includePremium: false)
            XCTAssertEqual(
                freeSnapshot.stories.count,
                10,
                "Free feed for \(edition.rawValue) should expose ten stories"
            )
        }
    }

    func testNewsSafetyFilterBlocksViolentContent() {
        XCTAssertFalse(
            NewsSafetyFilter.isSafe(
                title: "Breaking: missile attack kills civilians",
                summary: "details are still emerging"
            )
        )
        XCTAssertTrue(
            NewsSafetyFilter.isSafe(
                title: "School rooftop garden opens in Taipei",
                summary: "students learn food growing and science"
            )
        )
    }

    func testNewsCacheDayBucketUsesUTCDateKey() {
        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 4,
            day: 21,
            hour: 23,
            minute: 59
        )
        guard let date = components.date else {
            XCTFail("Expected a valid UTC date")
            return
        }

        XCTAssertEqual(NewsCacheDayBucket.dayKey(for: date), "2026-04-21")
    }

    func testPreferredStorySummaryKeepsFullTextWithoutAddingEllipsis() {
        let summary = """
        Students in three cities compared rainfall maps, local river levels, and school evacuation plans to understand how weather alerts change what families should prepare before class starts each morning.
        """

        let resolved = LiveCuratedNewsService.preferredStorySummary(
            summary: summary,
            fallbackTitle: "Fallback title"
        )

        XCTAssertEqual(resolved, summary)
        XCTAssertFalse(resolved.hasSuffix("…"))
        XCTAssertFalse(resolved.hasSuffix("..."))
    }

    func testPreferredStorySummaryFallsBackToTitleWhenSummaryIsEmpty() {
        let resolved = LiveCuratedNewsService.preferredStorySummary(
            summary: "   ",
            fallbackTitle: "NASA shares a new weather satellite update"
        )

        XCTAssertEqual(resolved, "NASA shares a new weather satellite update")
    }

    func testEnglishDisplayStorySummaryCompactsLongFeedCopyWithoutEllipsis() {
        let summary = """
        Students in several cities compared rainfall maps, river levels, school alerts, and changing bus routes so teachers could decide how to keep outdoor activities safe during the week.
        """

        let resolved = LiveCuratedNewsService.displayStorySummary(
            summary: summary,
            fallbackTitle: "Fallback title",
            edition: .unitedStatesEn,
            ageBand: .ages6to9
        )

        XCTAssertNotEqual(resolved, summary)
        XCTAssertFalse(resolved.hasSuffix("…"))
        XCTAssertFalse(resolved.hasSuffix("..."))
        XCTAssertLessThanOrEqual(resolved.split(separator: " ").count, 26)
        XCTAssertTrue(resolved.hasSuffix("."))
    }

    func testWithPremiumOnlyPreservesSafetyNotesAndAgeCopies() {
        let story = CuratedStory(
            id: "story-with-copy",
            source: service.allStories[0].source,
            region: .global,
            category: .science,
            marketFocus: [.taiwan],
            premiumOnly: false,
            safetyNotes: ["safe"],
            ageCopies: [
                .ages6to9: StoryCopy(
                    headline: "headline",
                    summary: "summary",
                    whyItMatters: "why",
                    talkPrompt: "prompt",
                    readingMinutes: 3
                )
            ]
        )

        let updated = story.withPremiumOnly(true)

        XCTAssertTrue(updated.premiumOnly)
        XCTAssertEqual(updated.safetyNotes, ["safe"])
        XCTAssertEqual(updated.ageCopies[.ages6to9]?.headline, "headline")
    }

    func testZhuyinConverterBuildsTaiwanFriendlySyllables() {
        XCTAssertEqual(ZhuyinPinyinConverter.bopomofo("tái"), "ㄊㄞˊ")
        XCTAssertEqual(ZhuyinPinyinConverter.bopomofo("wān"), "ㄨㄢ")
        XCTAssertEqual(ZhuyinPinyinConverter.bopomofo("xīn"), "ㄒㄧㄣ")
        XCTAssertEqual(ZhuyinPinyinConverter.bopomofo("biāo"), "ㄅㄧㄠ")
        XCTAssertEqual(ZhuyinPinyinConverter.bopomofo("tí"), "ㄊㄧˊ")
    }
}

private final class FailingNewsFeedURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

private final class RecordingNewsFeedURLProtocol: URLProtocol {
    private static let queue = DispatchQueue(label: "RecordingNewsFeedURLProtocol.queue")
    private static var requestedURLs: [String] = []

    static func reset() {
        queue.sync {
            requestedURLs = []
        }
    }

    static func snapshot() -> [String] {
        queue.sync {
            requestedURLs
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.queue.sync {
            Self.requestedURLs.append(url.absoluteString)
        }

        let (safeTitle, safeSummary): (String, String)
        if let host = url.host, host.contains("nhk.or.jp") {
            safeTitle = "子ども向けのやさしいニュース"
            safeSummary = "子どもたちが地図や科学の話を見ながら、世界の出来事を落ち着いて学べる内容です。"
        } else if let host = url.host, host.contains("pts.org.tw") || host.contains("feedburner.com") {
            safeTitle = "適合孩子閱讀的溫和新聞"
            safeSummary = "孩子可以用地圖和科學小知識，平穩認識世界正在發生的事情。"
        } else {
            safeTitle = "Gentle news for young readers"
            safeSummary = "Students compare maps, science ideas, and world updates in a calm kid-friendly briefing."
        }

        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Recorded Feed</title>
            <item>
              <title>\(safeTitle)</title>
              <link>\(url.absoluteString)#story</link>
              <description>\(safeSummary)</description>
              <pubDate>Wed, 22 Apr 2026 10:00:00 +0000</pubDate>
            </item>
          </channel>
        </rss>
        """

        guard let data = rss.data(using: .utf8) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotDecodeContentData))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/rss+xml; charset=utf-8"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class PremiumRewriteURLProtocol: URLProtocol {
    private static let queue = DispatchQueue(label: "PremiumRewriteURLProtocol.queue")
    private static var payload = "{}"
    private static var lastRequest: URLRequest?

    static func setPayload(_ payload: String) {
        queue.sync {
            self.payload = payload
        }
    }

    static func resetLastRequest() {
        queue.sync {
            lastRequest = nil
        }
    }

    static func lastRequestValue(forHTTPHeaderField field: String) -> String? {
        queue.sync {
            lastRequest?.value(forHTTPHeaderField: field)
        }
    }

    static func lastRequestURL() -> URL? {
        queue.sync {
            lastRequest?.url
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, url.host == "rewrite.example.com" else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Self.queue.sync {
            Self.lastRequest = request
        }

        let payload = Self.queue.sync { Self.payload }
        guard let data = payload.data(using: .utf8) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotDecodeContentData))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json; charset=utf-8"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
