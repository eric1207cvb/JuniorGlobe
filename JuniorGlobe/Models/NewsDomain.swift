//
//  NewsDomain.swift
//  JuniorGlobe
//

import Foundation

enum AudienceMarket: String, CaseIterable, Codable, Identifiable, Sendable {
    case unitedStates
    case taiwan
    case japan

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .unitedStates:
            return "美國"
        case .taiwan:
            return "台灣"
        case .japan:
            return "日本"
        }
    }

    var editorialFocus: String {
        switch self {
        case .unitedStates:
            return "美國版優先連結美洲與全球議題，幫孩子把在地生活和世界事件放在同一張地圖上。"
        case .taiwan:
            return "台灣版優先連結亞洲脈動與世界趨勢，避免只看單一國家，培養孩子的國際比較能力。"
        case .japan:
            return "日本版優先連結亞太與全球合作議題，讓孩子從周邊世界往外看見不同文化與解方。"
        }
    }

    var strategySummary: String {
        switch self {
        case .unitedStates:
            return "先給一則美洲最相關報導，再補歐洲、非洲、亞太與全球視角。"
        case .taiwan:
            return "先給一則台灣最有感的亞洲議題，再補拉美、非洲、歐洲與全球議題。"
        case .japan:
            return "先給一則日本最相關的亞太議題，再補美洲、歐洲、非洲與全球議題。"
        }
    }
}

enum AgeBand: String, CaseIterable, Codable, Identifiable, Sendable {
    case ages6to9
    case ages9to12

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ages6to9:
            return "6-9 歲"
        case .ages9to12:
            return "9-12 歲"
        }
    }

    var readingStyleDescription: String {
        switch self {
        case .ages6to9:
            return "使用短句、具體例子與明確因果，先講正在發生什麼，再說和孩子有什麼關係。"
        case .ages9to12:
            return "加入更多背景、比較與公民脈絡，讓孩子開始理解事件背後的制度與選擇。"
        }
    }

    func label(for edition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return label
        case .japanJa:
            switch self {
            case .ages6to9:
                return "6-9歳"
            case .ages9to12:
                return "9-12歳"
            }
        case .unitedStatesEn:
            switch self {
            case .ages6to9:
                return "Ages 6-9"
            case .ages9to12:
                return "Ages 9-12"
            }
        }
    }
}

enum WorldRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case northAmerica
    case latinAmerica
    case europe
    case africa
    case asiaPacific
    case global

    var id: String { rawValue }

    var label: String {
        switch self {
        case .northAmerica:
            return "北美"
        case .latinAmerica:
            return "拉美"
        case .europe:
            return "歐洲"
        case .africa:
            return "非洲"
        case .asiaPacific:
            return "亞太"
        case .global:
            return "全球"
        }
    }

    var sortOrder: Int {
        switch self {
        case .northAmerica:
            return 0
        case .latinAmerica:
            return 1
        case .europe:
            return 2
        case .africa:
            return 3
        case .asiaPacific:
            return 4
        case .global:
            return 5
        }
    }

    func label(for edition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return label
        case .japanJa:
            switch self {
            case .northAmerica:
                return "北米"
            case .latinAmerica:
                return "中南米"
            case .europe:
                return "ヨーロッパ"
            case .africa:
                return "アフリカ"
            case .asiaPacific:
                return "アジア太平洋"
            case .global:
                return "世界"
            }
        case .unitedStatesEn:
            switch self {
            case .northAmerica:
                return "North America"
            case .latinAmerica:
                return "Latin America"
            case .europe:
                return "Europe"
            case .africa:
                return "Africa"
            case .asiaPacific:
                return "Asia-Pacific"
            case .global:
                return "Global"
            }
        }
    }
}

enum StoryCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case science
    case climate
    case culture
    case civics
    case innovation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .science:
            return "科學"
        case .climate:
            return "環境"
        case .culture:
            return "文化"
        case .civics:
            return "公民"
        case .innovation:
            return "創新"
        }
    }

    func label(for edition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return label
        case .japanJa:
            switch self {
            case .science:
                return "科学"
            case .climate:
                return "環境"
            case .culture:
                return "文化"
            case .civics:
                return "市民社会"
            case .innovation:
                return "イノベーション"
            }
        case .unitedStatesEn:
            switch self {
            case .science:
                return "Science"
            case .climate:
                return "Climate"
            case .culture:
                return "Culture"
            case .civics:
                return "Civics"
            case .innovation:
                return "Innovation"
            }
        }
    }
}

enum SafetyRule: String, CaseIterable, Codable, Identifiable, Sendable {
    case noGraphicViolence
    case noSexualContent
    case noSubstances
    case noHateSpeech
    case kidContextOnly
    case verifiedSourcesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noGraphicViolence:
            return "不呈現血腥與驚悚細節"
        case .noSexualContent:
            return "不收錄腥羶色內容"
        case .noSubstances:
            return "不美化毒品、賭博或危險行為"
        case .noHateSpeech:
            return "不轉述仇恨言論與羞辱語句"
        case .kidContextOnly:
            return "只留下孩子能理解的必要背景"
        case .verifiedSourcesOnly:
            return "只用可追溯的權威來源"
        }
    }

    var detail: String {
        switch self {
        case .noGraphicViolence:
            return "若題材涉及災難或衝突，只保留安全知識、援助與修復，不描述畫面細節。"
        case .noSexualContent:
            return "直接排除成人導向、性暗示與不適合兒少的娛樂八卦。"
        case .noSubstances:
            return "不把成人消費或危險挑戰包裝成有趣內容。"
        case .noHateSpeech:
            return "避免讓孩子接觸會模仿或擴散傷害的語句。"
        case .kidContextOnly:
            return "6-9 歲版本先講重點與行動，9-12 歲版本再補制度與國際背景。"
        case .verifiedSourcesOnly:
            return "不採匿名社群貼文、未核實影音或缺乏編輯責任鏈的內容。"
        }
    }
}

struct TrustedSource: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let countryLabel: String
    let authorityLabel: String
    let reasonTrusted: String
    let preferredMarkets: [AudienceMarket]

    var contentLanguage: SourceContentLanguage {
        switch id {
        case "nhk", "nhk-live":
            return .japanese
        case "cna", "cna-live", "pts", "pts-live":
            return .traditionalChinese
        default:
            return .english
        }
    }

    func isCompatible(with edition: AppEdition) -> Bool {
        contentLanguage == edition.contentLanguage
    }

    func localizedCountryLabel(for edition: AppEdition) -> String {
        switch (countryLabel, edition) {
        case (_, .taiwanZhHant):
            return countryLabel
        case ("美國", .japanJa):
            return "アメリカ"
        case ("英國 / 全球", .japanJa):
            return "イギリス / 世界"
        case ("英國", .japanJa):
            return "イギリス"
        case ("澳洲", .japanJa):
            return "オーストラリア"
        case ("全球", .japanJa):
            return "世界"
        case ("日本", .japanJa):
            return "日本"
        case ("台灣", .japanJa):
            return "台湾"
        case ("美國", .unitedStatesEn):
            return "United States"
        case ("英國 / 全球", .unitedStatesEn):
            return "United Kingdom / Global"
        case ("英國", .unitedStatesEn):
            return "United Kingdom"
        case ("澳洲", .unitedStatesEn):
            return "Australia"
        case ("全球", .unitedStatesEn):
            return "Global"
        case ("日本", .unitedStatesEn):
            return "Japan"
        case ("台灣", .unitedStatesEn):
            return "Taiwan"
        default:
            return countryLabel
        }
    }

    func localizedAuthorityLabel(for edition: AppEdition) -> String {
        switch (authorityLabel, edition) {
        case (_, .taiwanZhHant):
            return authorityLabel
        case ("國際通訊社", .japanJa):
            return "国際通信社"
        case ("公共媒體", .japanJa):
            return "公共メディア"
        case ("國家通訊社", .japanJa):
            return "国営通信社"
        case ("政府機構", .japanJa):
            return "政府機関"
        case ("國際通訊社", .unitedStatesEn):
            return "Global Wire Service"
        case ("公共媒體", .unitedStatesEn):
            return "Public Broadcaster"
        case ("國家通訊社", .unitedStatesEn):
            return "National News Agency"
        case ("政府機構", .unitedStatesEn):
            return "Government Agency"
        default:
            return authorityLabel
        }
    }
}

struct StoryCopy: Codable, Hashable, Sendable {
    let headline: String
    let summary: String
    let understandingGuide: String
    let backgroundBrief: String
    let whyItMatters: String
    let talkPrompt: String
    let readingMinutes: Int

    init(
        headline: String,
        summary: String,
        understandingGuide: String = "",
        backgroundBrief: String = "",
        whyItMatters: String,
        talkPrompt: String,
        readingMinutes: Int
    ) {
        self.headline = headline
        self.summary = summary
        self.understandingGuide = understandingGuide
        self.backgroundBrief = backgroundBrief
        self.whyItMatters = whyItMatters
        self.talkPrompt = talkPrompt
        self.readingMinutes = readingMinutes
    }
}

struct CuratedStory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let source: TrustedSource
    let region: WorldRegion
    let category: StoryCategory
    let marketFocus: [AudienceMarket]
    let premiumOnly: Bool
    let safetyNotes: [String]
    let ageCopies: [AgeBand: StoryCopy]

    var isPremiumRewrite: Bool {
        premiumOnly && id.hasPrefix("premium-rewrite|")
    }

    func copy(for ageBand: AgeBand) -> StoryCopy {
        if let copy = ageCopies[ageBand] ?? ageCopies[.ages9to12] ?? ageCopies[.ages6to9] {
            return copy
        }

        preconditionFailure("Every story must include at least one age-specific copy.")
    }

    func withPremiumOnly(_ premiumOnly: Bool) -> CuratedStory {
        CuratedStory(
            id: id,
            source: source,
            region: region,
            category: category,
            marketFocus: marketFocus,
            premiumOnly: premiumOnly,
            safetyNotes: safetyNotes,
            ageCopies: ageCopies
        )
    }
}

struct EditorialPolicy: Codable, Sendable {
    let coverageGoals: [String]
    let verificationSteps: [String]
    let safetyRules: [SafetyRule]
}

struct FeedSnapshot: Codable, Sendable {
    let stories: [CuratedStory]
    let lockedStoryCount: Int
    let totalAvailableStoryCount: Int

    static let empty = FeedSnapshot(
        stories: [],
        lockedStoryCount: 0,
        totalAvailableStoryCount: 0
    )

    var visibleRegionCount: Int {
        Set(stories.map(\.region)).count
    }

    var visibleSourceCount: Int {
        Set(stories.map(\.source.id)).count
    }

    var visibleCategoryCount: Int {
        Set(stories.map(\.category)).count
    }
}

enum FeedDeliveryMode: String, Codable, Sendable {
    case live
    case cached
    case unavailable
    case sampleFallback
}

struct NewsFeedPresentation: Codable, Sendable {
    let snapshot: FeedSnapshot
    let trustedSources: [TrustedSource]
    let deliveryMode: FeedDeliveryMode
    let lastUpdatedAt: Date?
    let dayKey: String?
}
