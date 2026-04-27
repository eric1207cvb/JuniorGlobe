//
//  DemoCuratedNewsService.swift
//  JuniorGlobe
//

import Foundation

protocol CuratedNewsServicing: Sendable {
    var editorialPolicy: EditorialPolicy { get }
    func feed(for edition: AppEdition, ageBand: AgeBand, includePremium: Bool) -> FeedSnapshot
    func trustedSources(for edition: AppEdition) -> [TrustedSource]
}

extension CuratedNewsServicing {
    func feed(for market: AudienceMarket, ageBand: AgeBand, includePremium: Bool) -> FeedSnapshot {
        feed(for: .defaultEdition(for: market), ageBand: ageBand, includePremium: includePremium)
    }

    func trustedSources(for market: AudienceMarket) -> [TrustedSource] {
        trustedSources(for: .defaultEdition(for: market))
    }
}

struct DemoCuratedNewsService: CuratedNewsServicing {
    let editorialPolicy = EditorialPolicy(
        coverageGoals: [
            "每個市場首頁都要同時看見在地相關性與其他洲際視角。",
            "避免單一衝突、單一大國或單一娛樂題材長期主導版面。",
            "優先選能培養比較、同理與解方思考的世界新聞。"
        ],
        verificationSteps: [
            "優先採用 AP、Reuters、BBC、NHK、中央社、公視等可追溯編輯來源。",
            "重要議題至少做二次交叉查核，或以通訊社加公共機構資訊互證。",
            "不收錄匿名貼文、未核實短影音、轉傳截圖與開放留言。"
        ],
        safetyRules: SafetyRule.allCases
    )

    var allStories: [CuratedStory] {
        Catalog.allStories
    }

    func sampleStories(for edition: AppEdition) -> [CuratedStory] {
        Catalog.stories(for: edition)
    }

    func feed(for edition: AppEdition, ageBand: AgeBand, includePremium: Bool) -> FeedSnapshot {
        let market = edition.market
        let stories = sampleStories(for: edition)
        let premiumLimit = storyLimit(for: ageBand, includePremium: true)
        let freeLimit = storyLimit(for: ageBand, includePremium: false)
        let premiumFeed = buildBalancedFeed(from: stories, market: market, ageBand: ageBand, limit: premiumLimit)
        let freeStories = stories.filter { $0.premiumOnly == false }
        let freeFeed = buildBalancedFeed(from: freeStories, market: market, ageBand: ageBand, limit: freeLimit)

        return FeedSnapshot(
            stories: includePremium ? premiumFeed : freeFeed,
            lockedStoryCount: includePremium ? 0 : max(0, premiumFeed.count - freeFeed.count),
            totalAvailableStoryCount: premiumFeed.count
        )
    }

    func trustedSources(for edition: AppEdition) -> [TrustedSource] {
        let market = edition.market
        return Catalog.sources(for: edition).sorted { lhs, rhs in
            let leftScore = sourcePriority(lhs, market: market)
            let rightScore = sourcePriority(rhs, market: market)
            if leftScore != rightScore {
                return leftScore > rightScore
            }

            return lhs.name < rhs.name
        }
    }

    private func buildBalancedFeed(
        from stories: [CuratedStory],
        market: AudienceMarket,
        ageBand: AgeBand,
        limit: Int
    ) -> [CuratedStory] {
        let sortedStories = stories.sorted { lhs, rhs in
            let leftScore = storyPriority(lhs, market: market)
            let rightScore = storyPriority(rhs, market: market)

            if leftScore != rightScore {
                return leftScore > rightScore
            }

            if lhs.region.sortOrder != rhs.region.sortOrder {
                return lhs.region.sortOrder < rhs.region.sortOrder
            }

            return lhs.id < rhs.id
        }

        var selectedStories: [CuratedStory] = []
        var seenRegions: Set<WorldRegion> = []
        var seenCategories: Set<StoryCategory> = []
        var seenSources: Set<String> = []

        for story in sortedStories where seenRegions.contains(story.region) == false {
            selectedStories.append(story)
            seenRegions.insert(story.region)
            seenCategories.insert(story.category)
            seenSources.insert(story.source.id)

            if selectedStories.count == limit {
                return selectedStories
            }
        }

        if ageBand == .ages9to12 {
            for story in sortedStories
            where selectedStories.contains(story) == false && seenCategories.contains(story.category) == false {
                selectedStories.append(story)
                seenCategories.insert(story.category)
                seenSources.insert(story.source.id)

                if selectedStories.count == limit {
                    return selectedStories
                }
            }

            for story in sortedStories
            where selectedStories.contains(story) == false && seenSources.contains(story.source.id) == false {
                selectedStories.append(story)
                seenSources.insert(story.source.id)

                if selectedStories.count == limit {
                    return selectedStories
                }
            }
        }

        for story in sortedStories where selectedStories.contains(story) == false {
            selectedStories.append(story)

            if selectedStories.count == limit {
                break
            }
        }

        return selectedStories
    }

    private func storyLimit(for ageBand: AgeBand, includePremium: Bool) -> Int {
        SubscriptionPolicy.current(isPremium: includePremium, ageBand: ageBand).visibleStoryLimit
    }

    private func storyPriority(_ story: CuratedStory, market: AudienceMarket) -> Int {
        var score = story.marketFocus.contains(market) ? 5 : 0
        score += sourcePriority(story.source, market: market)

        switch (market, story.region) {
        case (.unitedStates, .northAmerica), (.taiwan, .asiaPacific), (.japan, .asiaPacific):
            score += 2
        case (_, .global):
            score += 1
        default:
            break
        }

        if story.premiumOnly == false {
            score += 1
        }

        return score
    }

    private func sourcePriority(_ source: TrustedSource, market: AudienceMarket) -> Int {
        source.preferredMarkets.contains(market) ? 2 : 1
    }
}

private struct DemoLocalizedStoryCopy {
    let youngerHeadline: String
    let youngerSummary: String
    let olderHeadline: String
    let olderSummary: String
}

private struct DemoStorySeed {
    let idStem: String
    let region: WorldRegion
    let category: StoryCategory
    let marketFocus: [AudienceMarket]
    let premiumOnly: Bool
    let sourceByEdition: [AppEdition: TrustedSource]
    let copyByEdition: [AppEdition: DemoLocalizedStoryCopy]

    func story(for edition: AppEdition) -> CuratedStory? {
        guard let source = sourceByEdition[edition], let copy = copyByEdition[edition] else {
            return nil
        }

        return CuratedStory(
            id: "\(edition.rawValue)-\(idStem)",
            source: source,
            region: region,
            category: category,
            marketFocus: marketFocus,
            premiumOnly: premiumOnly,
            safetyNotes: localizedSampleSafetyNotes(for: edition),
            ageCopies: [
                .ages6to9: StoryCopy(
                    headline: copy.youngerHeadline,
                    summary: copy.youngerSummary,
                    backgroundBrief: StoryMetadataClassifier.backgroundBrief(
                        for: category,
                        region: region,
                        ageBand: .ages6to9,
                        edition: edition
                    ),
                    whyItMatters: StoryMetadataClassifier.whyItMatters(
                        for: category,
                        region: region,
                        ageBand: .ages6to9,
                        edition: edition
                    ),
                    talkPrompt: StoryMetadataClassifier.talkPrompt(
                        for: category,
                        ageBand: .ages6to9,
                        edition: edition
                    ),
                    readingMinutes: 3
                ),
                .ages9to12: StoryCopy(
                    headline: copy.olderHeadline,
                    summary: copy.olderSummary,
                    backgroundBrief: StoryMetadataClassifier.backgroundBrief(
                        for: category,
                        region: region,
                        ageBand: .ages9to12,
                        edition: edition
                    ),
                    whyItMatters: StoryMetadataClassifier.whyItMatters(
                        for: category,
                        region: region,
                        ageBand: .ages9to12,
                        edition: edition
                    ),
                    talkPrompt: StoryMetadataClassifier.talkPrompt(
                        for: category,
                        ageBand: .ages9to12,
                        edition: edition
                    ),
                    readingMinutes: premiumOnly ? 5 : 4
                )
            ]
        )
    }
}

private func localizedSampleSafetyNotes(for edition: AppEdition) -> [String] {
    switch edition {
    case .taiwanZhHant:
        return [
            "只保留孩子需要的背景脈絡",
            "示範樣本不含血腥或成人細節"
        ]
    case .japanJa:
        return [
            "子どもに必要な背景だけを残している",
            "見本の内容は暴力的・成人向けの細部を含まない"
        ]
    case .unitedStatesEn:
        return [
            "Only kid-relevant context is kept in the sample.",
            "The sample leaves out graphic and adult details."
        ]
    }
}

private enum Catalog {
    static let ap = TrustedSource(
        id: "ap",
        name: "Associated Press",
        countryLabel: "美國",
        authorityLabel: "國際通訊社",
        reasonTrusted: "全球採訪網絡大、勘誤流程成熟，適合當作第一手國際基礎報導來源。",
        preferredMarkets: [.unitedStates]
    )

    static let reuters = TrustedSource(
        id: "reuters",
        name: "Reuters",
        countryLabel: "英國 / 全球",
        authorityLabel: "國際通訊社",
        reasonTrusted: "跨國採訪與市場、政策、科技報導完整，便於做國際交叉比對。",
        preferredMarkets: [.unitedStates]
    )

    static let bbc = TrustedSource(
        id: "bbc",
        name: "BBC",
        countryLabel: "英國",
        authorityLabel: "公共媒體",
        reasonTrusted: "公共媒體編採標準清楚，國際、科學與教育題材深度穩定。",
        preferredMarkets: [.unitedStates]
    )

    static let pbs = TrustedSource(
        id: "pbs",
        name: "PBS News",
        countryLabel: "美國",
        authorityLabel: "公共媒體",
        reasonTrusted: "公共媒體取材節奏穩定，適合孩子理解世界與公共議題。",
        preferredMarkets: [.unitedStates]
    )

    static let nasa = TrustedSource(
        id: "nasa",
        name: "NASA",
        countryLabel: "美國",
        authorityLabel: "政府機構",
        reasonTrusted: "官方科學與太空資訊可追溯，適合示範高可信科學來源。",
        preferredMarkets: [.unitedStates]
    )

    static let nhk = TrustedSource(
        id: "nhk",
        name: "NHK World-Japan",
        countryLabel: "日本",
        authorityLabel: "公共媒體",
        reasonTrusted: "日本公共媒體，適合亞太議題與日本受眾導向內容的在地校準。",
        preferredMarkets: [.japan]
    )

    static let cna = TrustedSource(
        id: "cna",
        name: "中央社",
        countryLabel: "台灣",
        authorityLabel: "國家通訊社",
        reasonTrusted: "具穩定國際線與中文編譯能力，適合台灣市場與中文兒少改寫。",
        preferredMarkets: [.taiwan]
    )

    static let pts = TrustedSource(
        id: "pts",
        name: "公視新聞網",
        countryLabel: "台灣",
        authorityLabel: "公共媒體",
        reasonTrusted: "公共媒體脈絡清楚，適合兒少安全與公民素養導向的議題改寫。",
        preferredMarkets: [.taiwan]
    )

    static var allStories: [CuratedStory] {
        AppEdition.allCases.flatMap { stories(for: $0) }
    }

    static func sources(for edition: AppEdition) -> [TrustedSource] {
        switch edition {
        case .taiwanZhHant:
            return [cna, pts]
        case .japanJa:
            return [nhk]
        case .unitedStatesEn:
            return [ap, reuters, bbc, pbs, nasa]
        }
    }

    static func stories(for edition: AppEdition) -> [CuratedStory] {
        seeds.compactMap { $0.story(for: edition) }
    }

    private static let seeds: [DemoStorySeed] = [
        DemoStorySeed(
            idStem: "school-rooftop-gardens",
            region: .northAmerica,
            category: .climate,
            marketFocus: [.unitedStates],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: ap
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "北美學校把屋頂變成降溫小菜園",
                    youngerSummary: "北美有些學校在屋頂種蔬菜和香草，讓校舍比較不熱，也讓孩子學食物和天氣的關係。",
                    olderHeadline: "北美校園試驗屋頂菜園，把降溫和食農課放在一起",
                    olderSummary: "部分學校把閒置屋頂改成小型菜園，兼顧降溫、雨水利用和學生的食農學習。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "北米の学校で屋上菜園が広がる",
                    youngerSummary: "北米の一部の学校では、屋上で野菜を育てて校舎の暑さをやわらげ、食べものの学びにもつなげている。",
                    olderHeadline: "北米の学校が屋上菜園を広げ、暑さ対策と食の学びを両立",
                    olderSummary: "使われていなかった屋上を小さな菜園に変え、気温を下げながら雨水利用や食育にも役立てている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "North American schools turn rooftops into cooling gardens",
                    youngerSummary: "Some schools are growing vegetables and herbs on rooftops so buildings stay cooler and kids can learn where food comes from.",
                    olderHeadline: "North American schools test rooftop gardens for cooling and food learning",
                    olderSummary: "Schools are converting unused rooftops into small gardens that support cooler buildings, rainwater use, and hands-on food lessons."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "taiwan-japan-safety-maps",
            region: .asiaPacific,
            category: .civics,
            marketFocus: [.taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: pts,
                .japanJa: nhk,
                .unitedStatesEn: reuters
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "台灣和日本的小朋友一起學看安全地圖",
                    youngerSummary: "台日學校分享怎麼畫出安全路線圖，讓孩子知道上學、放學和集合時要往哪裡走。",
                    olderHeadline: "台日校園交流防災地圖設計，把避難路線做得更容易理解",
                    olderSummary: "台灣與日本學校交流防災教育做法，重點放在如何用簡單圖像讓學生記住避難路線與集合點。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "台湾と日本の学校がわかりやすい安全マップを学び合う",
                    youngerSummary: "学校どうしで避難の道や集まる場所を見やすく伝える地図を紹介し合い、子どもが動き方を覚えやすくしている。",
                    olderHeadline: "台湾と日本の学校が防災マップを見直し、避難の理解を深める",
                    olderSummary: "両地域の学校は、簡単な記号と色分けを使って避難ルートや集合場所を覚えやすくする方法を共有している。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Taiwan and Japan classrooms test simpler safety maps",
                    youngerSummary: "Teachers are sharing easy route maps so children can remember where to walk and where to gather during drills.",
                    olderHeadline: "Taiwan and Japan schools redesign safety maps so students can follow them faster",
                    olderSummary: "Schools are comparing color-coded symbols and simpler route guides to help students understand evacuation paths and meeting points."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "europe-library-kits",
            region: .europe,
            category: .science,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: bbc
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "歐洲圖書館借出科學工具箱",
                    youngerSummary: "一些歐洲圖書館除了借書，也借顯微鏡和簡單實驗箱，讓孩子回家也能做小研究。",
                    olderHeadline: "歐洲圖書館把科學工具做成借閱服務，擴大孩子的探索機會",
                    olderSummary: "多地圖書館把顯微鏡、感測器與實驗套件納入借閱品項，降低家庭接觸科學工具的門檻。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "ヨーロッパの図書館が科学キットを貸し出す",
                    youngerSummary: "本だけでなく、顕微鏡や小さな実験セットも借りられる図書館が増え、家でも調べ学習がしやすくなっている。",
                    olderHeadline: "ヨーロッパの図書館が科学道具の貸し出しを広げ、学びの入口を増やす",
                    olderSummary: "顕微鏡やセンサーを借りられる仕組みが広がり、家庭でも科学的な観察を始めやすくなっている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "European libraries lend science kits to families",
                    youngerSummary: "Some libraries now lend microscopes and simple experiment boxes so children can keep exploring after they go home.",
                    olderHeadline: "European libraries expand science-kit lending to widen access for kids",
                    olderSummary: "Libraries are adding microscopes, sensors, and small experiment kits to lending shelves so more families can try science tools."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "kenya-solar-reading-room",
            region: .africa,
            category: .innovation,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: reuters
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "肯亞社區用太陽能點亮閱讀小屋",
                    youngerSummary: "肯亞有些社區把太陽能板裝在閱讀小屋上，讓孩子放學後也能安心看書和做功課。",
                    olderHeadline: "肯亞閱讀空間結合太陽能，讓社區在電力不足時也能持續學習",
                    olderSummary: "部分社區利用太陽能設備支撐晚間照明，讓孩子與家庭在電力不穩定時仍保有閱讀空間。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "ケニアの読書スペースを太陽の光が支える",
                    youngerSummary: "太陽光パネルを使って明かりをつけることで、放課後でも子どもたちが本を読める場所が増えている。",
                    olderHeadline: "ケニアで太陽光を使う読書スペースが広がり、学びを支える",
                    olderSummary: "電力が安定しない地域でも、太陽光設備で夜の照明を確保し、地域の学びの場を続けやすくしている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Kenyan reading rooms stay open with solar power",
                    youngerSummary: "Some community reading rooms use solar panels so children can read and do homework after school.",
                    olderHeadline: "Solar-powered reading rooms in Kenya keep learning going after dark",
                    olderSummary: "Communities are using solar systems to support evening lighting so children and families can keep learning when power is unreliable."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "school-lunch-exchange",
            region: .latinAmerica,
            category: .culture,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: pbs
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "秘魯和其他地方的孩子交換午餐故事",
                    youngerSummary: "老師帶著孩子介紹午餐盒裡常見的食物，大家發現不同國家都有特別的味道和習慣。",
                    olderHeadline: "不同國家的學校用午餐文化交流，讓孩子從食物理解生活背景",
                    olderSummary: "透過介紹午餐內容、食材來源與家庭習慣，孩子能比較不同地方的環境和飲食文化。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "ペルーとほかの地域の学校が昼食の文化を紹介し合う",
                    youngerSummary: "お弁当や給食に入る食べものを見せ合い、国によって味や習慣がちがうことを楽しく学んでいる。",
                    olderHeadline: "学校どうしが昼食文化を比べ、食べものから生活のちがいを学ぶ",
                    olderSummary: "献立や食材の背景を比べることで、地域ごとの気候や家庭の習慣まで考えられる交流になっている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Schools compare lunch routines across Peru and other regions",
                    youngerSummary: "Children are sharing what usually appears in their lunch boxes and finding out that different places have different food habits.",
                    olderHeadline: "School lunch exchanges help students compare food, climate, and daily routines",
                    olderSummary: "Students are using lunch comparisons to talk about ingredients, local climate, and family routines in different parts of the world."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "canada-park-shade-maps",
            region: .northAmerica,
            category: .civics,
            marketFocus: [.unitedStates],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: pts,
                .japanJa: nhk,
                .unitedStatesEn: pbs
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "加拿大公園畫出涼爽樹蔭地圖",
                    youngerSummary: "有些城市把公園裡的大樹、陰影和休息椅標成地圖，讓孩子天熱時更容易找到舒服的地方玩。",
                    olderHeadline: "加拿大城市替公園製作樹蔭地圖，幫家庭安排更安全的戶外時間",
                    olderSummary: "部分城市把樹蔭、飲水點與休息區做成簡單地圖，讓家庭在高溫日更容易安排安全的戶外活動。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "カナダの公園で木かげマップづくりが進む",
                    youngerSummary: "大きな木の下や休める場所を地図にして、暑い日でも子どもがすごしやすい公園にしようとしている。",
                    olderHeadline: "カナダの都市が公園の木かげマップを作り、暑い日の外遊びを助ける",
                    olderSummary: "木かげや水飲み場、休けい場所をわかりやすく示すことで、家族が暑い日の過ごし方を考えやすくしている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Canadian parks map cool shady spots for families",
                    youngerSummary: "Some cities are marking big trees and cool benches on park maps so children can find comfortable places to play on hot days.",
                    olderHeadline: "Canadian cities are mapping shade in parks to help families plan safer outdoor time",
                    olderSummary: "Cities are adding shade trees, water points, and rest areas to simple park maps so families can choose safer places during hot weather."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "brazil-rain-bus-stops",
            region: .latinAmerica,
            category: .climate,
            marketFocus: [.unitedStates, .taiwan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: reuters
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "巴西公車站加上接雨水的小屋簷",
                    youngerSummary: "有些公車站把雨水收進小水箱，還多了遮陽屋簷，讓大家等車時比較涼，也能把水拿來照顧植物。",
                    olderHeadline: "巴西部分公車站結合集水與遮陽設計，把候車空間做得更能適應天氣",
                    olderSummary: "新式公車站同時提供遮陽、收集雨水與灌溉綠化用途，讓城市在炎熱與雨季時都更有準備。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "ブラジルのバス停に雨水タンクと日よけが増える",
                    youngerSummary: "雨をためる小さなタンクと屋根をつけて、暑い日でも待ちやすくし、たまった水を植物にも使っている。",
                    olderHeadline: "ブラジルの新しいバス停が集水と日よけを組み合わせ、天気への備えを強める",
                    olderSummary: "雨水の活用と強い日差しへの対策を一つの場所で進めることで、街の移動空間を天候に強くしている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Brazilian bus stops catch rain and give more shade",
                    youngerSummary: "Some bus stops now collect rainwater and add bigger roofs so children and families can wait in cooler spaces.",
                    olderHeadline: "Brazilian bus stops combine shade and rainwater systems to handle changing weather",
                    olderSummary: "Updated bus stops are pairing larger shaded roofs with rainwater tanks so cities can create cooler waiting spaces and support nearby plants."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "europe-repair-clubs",
            region: .europe,
            category: .innovation,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: bbc
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "歐洲學校開修理小俱樂部",
                    youngerSummary: "孩子一起學著把壞掉的玩具、檯燈和小風扇修好，發現很多東西不用馬上丟掉。",
                    olderHeadline: "歐洲校園把修理俱樂部變成生活課，讓孩子從動手做學資源循環",
                    olderSummary: "不少學校把簡單修理活動放進課後社團，讓學生透過拆解、檢查和再利用理解資源循環。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "ヨーロッパの学校でなおして使うクラブが人気に",
                    youngerSummary: "こわれたおもちゃや小さな電気製品をみんなで直しながら、すぐにすてなくてもよいことを学んでいる。",
                    olderHeadline: "ヨーロッパの学校が修理クラブを広げ、ものを長く使う力を育てる",
                    olderSummary: "分解して原因を見つけ、部品を替えてもう一度使う経験を通して、資源を大切にする考え方を学んでいる。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "European school repair clubs help kids fix and reuse things",
                    youngerSummary: "Children are learning to repair toys, lamps, and small fans so fewer useful things get thrown away.",
                    olderHeadline: "European school repair clubs turn fixing broken items into everyday learning",
                    olderSummary: "Students are using after-school repair sessions to practice problem solving and learn how reusing items can reduce waste."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "south-africa-story-radio",
            region: .africa,
            category: .culture,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: pts,
                .japanJa: nhk,
                .unitedStatesEn: pbs
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "南非孩子把社區故事說進校園廣播",
                    youngerSummary: "學校的小小廣播站請孩子講家人和社區的故事，讓大家聽見不同語言和不同生活經驗。",
                    olderHeadline: "南非校園廣播邀孩子記錄社區故事，讓語言和生活記憶被更多人聽見",
                    olderSummary: "學生透過校園廣播分享家庭故事、地方語言與社區新聞，讓不同背景的孩子更了解彼此的生活。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "南アフリカの学校ラジオが町の物語を届ける",
                    youngerSummary: "子どもたちが家族や町の話をラジオで伝え、いろいろなことばやくらしを聞ける時間をつくっている。",
                    olderHeadline: "南アフリカの学校ラジオが地域の物語を記録し、多様な声をつなぐ",
                    olderSummary: "学校ラジオで地域の言葉や家族の経験を紹介することで、子どもどうしが違う背景を理解しやすくなっている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "South African school radio shares neighborhood stories",
                    youngerSummary: "Children are using school radio to tell family and community stories so classmates can hear different languages and experiences.",
                    olderHeadline: "South African school radio helps students record local stories and hear more voices",
                    olderSummary: "Students are turning school radio into a space for neighborhood stories, local languages, and shared understanding across different communities."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "asia-water-listening-stations",
            region: .asiaPacific,
            category: .science,
            marketFocus: [.taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: ap
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "亞太學校做會聽水聲的小站點",
                    youngerSummary: "孩子把簡單感測器放在溪流邊，聽水流變化、記錄下雨後的聲音，學習怎麼照顧附近的水。",
                    olderHeadline: "亞太學校用小感測站觀察水流變化，讓孩子從聲音學河川科學",
                    olderSummary: "學生在溪流周邊設置簡單感測器，記錄水聲和流速變化，學著把在地觀察連結到科學判讀。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "アジア太平洋の学校が水の音を聞く観測ポイントをつくる",
                    youngerSummary: "川の近くに小さなセンサーを置いて、水の流れや雨のあとの音のちがいを調べている。",
                    olderHeadline: "アジア太平洋の学校が水の音を記録し、川の変化を学ぶ",
                    olderSummary: "子どもたちは川辺の小さな観測ポイントで水音や流れの変化を調べ、地域の水環境を科学的に見ている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Asia-Pacific schools build little stations to listen to rivers",
                    youngerSummary: "Children are placing simple sensors near streams to notice how water sounds change after rain.",
                    olderHeadline: "Asia-Pacific schools use small listening stations to study changing river sounds",
                    olderSummary: "Students are using simple stream sensors to compare water sounds and flow changes, connecting local observations to science lessons."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "global-weather-postcards",
            region: .global,
            category: .culture,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: false,
            sourceByEdition: [
                .taiwanZhHant: pts,
                .japanJa: nhk,
                .unitedStatesEn: bbc
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "世界各地的孩子互寄天氣明信片",
                    youngerSummary: "不同地方的班級把今天的天空、風和溫度畫成明信片寄給彼此，看看每天的天氣有什麼不一樣。",
                    olderHeadline: "跨國班級互寄天氣明信片，讓孩子從日常觀察比較世界各地的生活",
                    olderSummary: "學生透過記錄天空、溫度與衣著，再和遠方學校交換明信片，理解天氣如何影響不同地方的生活安排。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "世界の子どもたちが天気のポストカードを送り合う",
                    youngerSummary: "空の色や風、今日の気温をカードにして送り合い、場所ごとの天気のちがいを楽しく見つけている。",
                    olderHeadline: "世界の学校が天気ポストカードを交換し、くらしのちがいを比べる",
                    olderSummary: "空のようすや気温、着ている服をカードにまとめて交換することで、天気が生活にどう関わるかを考えている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Kids around the world trade weather postcards",
                    youngerSummary: "Classes are drawing the sky, wind, and temperature on postcards so they can compare what a normal day feels like in other places.",
                    olderHeadline: "Schools are swapping weather postcards to compare daily life in different places",
                    olderSummary: "Students are sharing notes about sky conditions, temperature, and clothing choices to see how weather shapes everyday routines around the world."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "japan-night-sky-clubs",
            region: .asiaPacific,
            category: .science,
            marketFocus: [.japan],
            premiumOnly: true,
            sourceByEdition: [
                .taiwanZhHant: pts,
                .japanJa: nhk,
                .unitedStatesEn: ap
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "日本學校的觀星社一起找春天的星星",
                    youngerSummary: "日本有些學校帶孩子在晚上觀星，學著辨認星座，還會記錄看到的月亮變化。",
                    olderHeadline: "日本校園觀星社把天文活動做成長期記錄，讓孩子學會觀察與比較",
                    olderSummary: "學校社團透過持續觀測月相與星空變化，把天文活動和紀錄能力結合，培養學生的科學習慣。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "日本の観星クラブが春の星を記録する",
                    youngerSummary: "学校のクラブで星座を見つけたり、月の形の変化をノートに書いたりして、空の様子を楽しみながら学んでいる。",
                    olderHeadline: "日本の観星クラブが月と星の変化を長く記録し、観察の力を育てる",
                    olderSummary: "継続して月の形や星空を比べる活動を通して、答えを急がずに観察を積み重ねる科学の姿勢を学んでいる。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Japanese student sky clubs keep monthly moon logs",
                    youngerSummary: "Students are spotting constellations and writing down moon changes so they can notice patterns in the night sky.",
                    olderHeadline: "Japanese school sky clubs turn moon watching into long-term science notes",
                    olderSummary: "Clubs are combining regular observations of moon phases and stars to help students build habits of comparison and record keeping."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "pacific-coral-teams",
            region: .global,
            category: .climate,
            marketFocus: [.taiwan, .japan, .unitedStates],
            premiumOnly: true,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: nasa
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "太平洋的科學家一起幫珊瑚找新家",
                    youngerSummary: "不同島國的研究人員合作照顧珊瑚，希望讓海裡的小生物有更好的家。",
                    olderHeadline: "太平洋多國合作修復珊瑚礁，讓海洋保育從研究走向行動",
                    olderSummary: "研究團隊透過監測水溫、移植珊瑚與分享數據，嘗試提升珊瑚礁對氣候變化的適應能力。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "太平洋の研究チームがサンゴを守る作戦を進める",
                    youngerSummary: "いろいろな島の研究者が力を合わせて、海の生きもののすみかになるサンゴを守ろうとしている。",
                    olderHeadline: "太平洋の研究チームがサンゴ保全でデータを共有し、海を守る行動を進める",
                    olderSummary: "水温の観測やサンゴの移植を協力して進め、気候変化に強い海の環境をつくる方法を探っている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "Pacific coral teams share ways to protect sea life",
                    youngerSummary: "Scientists from different islands are working together so coral reefs can stay healthy for the animals that live there.",
                    olderHeadline: "Pacific coral teams share data to move reef recovery from research to action",
                    olderSummary: "Researchers are comparing water temperatures, coral transplants, and shared data to help reefs adapt to changing ocean conditions."
                )
            ]
        ),
        DemoStorySeed(
            idStem: "global-weather-satellite",
            region: .global,
            category: .science,
            marketFocus: [.unitedStates, .taiwan, .japan],
            premiumOnly: true,
            sourceByEdition: [
                .taiwanZhHant: cna,
                .japanJa: nhk,
                .unitedStatesEn: nasa
            ],
            copyByEdition: [
                .taiwanZhHant: DemoLocalizedStoryCopy(
                    youngerHeadline: "新的天氣衛星像幫地球拍照的小幫手",
                    youngerSummary: "科學家把新的天氣衛星送上天，想更快知道雲和風怎麼移動，幫大家準備每天的天氣。",
                    olderHeadline: "新一代氣象衛星提升全球觀測能力，讓預報更快更精細",
                    olderSummary: "新衛星能更密集地觀測雲層、風場與溫度變化，幫助各地氣象單位提升預報與早期準備能力。"
                ),
                .japanJa: DemoLocalizedStoryCopy(
                    youngerHeadline: "新しい気象衛星が空の様子を細かく見る",
                    youngerSummary: "新しい衛星が雲や風の動きをもっと早く見つけられるようになり、毎日の天気の準備に役立っている。",
                    olderHeadline: "新しい気象衛星が世界の観測を細かくし、予報の力を高める",
                    olderSummary: "雲や風、気温の変化をよりこまかく観測できるようになり、各地の気象機関が早めに備える助けになっている。"
                ),
                .unitedStatesEn: DemoLocalizedStoryCopy(
                    youngerHeadline: "A new weather satellite gives forecasters sharper sky pictures",
                    youngerSummary: "Scientists launched a new satellite to spot cloud and wind changes faster and help people get ready for the day.",
                    olderHeadline: "A new weather satellite sharpens global forecasts and early warnings",
                    olderSummary: "The satellite can track clouds, winds, and temperature changes more often, helping forecast teams improve planning and early alerts."
                )
            ]
        )
    ]
}
