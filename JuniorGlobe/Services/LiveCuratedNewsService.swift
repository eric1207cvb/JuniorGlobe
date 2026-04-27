//
//  LiveCuratedNewsService.swift
//  JuniorGlobe
//

import Foundation

enum NewsCacheDayBucket {
    nonisolated static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct NewsSafetyFilter {
    nonisolated private static let latinBlockedPatterns: [NSRegularExpression] = [
        #"\bkilled\b"#,
        #"\bmurder(?:ed|er|ers|s)?\b"#,
        #"\bshoot(?:ing|ings|out|outs)?\b"#,
        #"\bbomb(?:ed|ing|ings|s)?\b"#,
        #"\bmissiles?\b"#,
        #"\bwar\b"#,
        #"\bassault(?:ed|ing|s)?\b"#,
        #"\bstab(?:bed|bing|s)?\b"#,
        #"\bdead\s+body\b"#,
        #"\brape(?:d|s)?\b"#,
        #"\bporn(?:ography)?\b"#,
        #"\bsex\s+tape\b"#,
        #"\bdrug\s+cartel\b"#,
        #"\bcasinos?\b"#,
        #"\bbetting\b"#,
        #"\bterror(?:ist|ists|ism)?\b"#,
        #"\bmassacre(?:d|s)?\b"#
    ].compactMap { pattern in
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    nonisolated private static let cjkBlockedKeywords = [
        "槍擊", "爆炸", "炸彈", "飛彈", "戰爭", "屍體", "血腥", "性侵", "色情", "賭博", "毒品",
        "銃撃", "爆弾", "戦争", "殺害", "性的", "ポルノ", "麻薬", "賭博"
    ]

    nonisolated static func isSafe(title: String, summary: String) -> Bool {
        let haystack = "\(title) \(summary)"
        let latinRange = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)

        if latinBlockedPatterns.contains(where: { regex in
            regex.firstMatch(in: haystack, options: [], range: latinRange) != nil
        }) {
            return false
        }

        let normalized = haystack.lowercased()
        return cjkBlockedKeywords.contains(where: normalized.contains) == false
    }
}

private enum HTMLTextSanitizer {
    nonisolated private static let entityPattern = try? NSRegularExpression(
        pattern: #"&(#\d+|#x[0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]+);"#,
        options: []
    )

    nonisolated private static let namedEntities: [String: String] = [
        "amp": "&",
        "apos": "'",
        "gt": ">",
        "lt": "<",
        "nbsp": " ",
        "quot": "\"",
        "ensp": " ",
        "emsp": " ",
        "thinsp": " ",
        "zwnj": "",
        "zwj": "",
        "hellip": "...",
        "ndash": "-",
        "mdash": "-",
        "lsquo": "'",
        "rsquo": "'",
        "ldquo": "\"",
        "rdquo": "\"",
        "middot": "·",
        "bull": "•",
        "copy": "©",
        "reg": "®",
        "trade": "™"
    ]

    nonisolated static func clean(_ text: String) -> String {
        let decoded = decodeRecursively(text, maxPasses: 2)
        let withoutTags = decoded.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let cleaned = decodeRecursively(withoutTags, maxPasses: 1)

        return normalizeWhitespace(in: cleaned)
    }

    nonisolated private static func decodeRecursively(_ text: String, maxPasses: Int) -> String {
        var current = text

        for _ in 0..<maxPasses {
            let decoded = decodeEntities(in: current)
            if decoded == current {
                break
            }
            current = decoded
        }

        return current
    }

    nonisolated private static func decodeEntities(in text: String) -> String {
        guard
            let entityPattern,
            text.isEmpty == false
        else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = entityPattern.matches(in: text, options: [], range: range)
        guard matches.isEmpty == false else {
            return text
        }

        var result = text
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range, in: result),
                let entityRange = Range(match.range(at: 1), in: result)
            else {
                continue
            }

            let entity = String(result[entityRange])
            if let decoded = decode(entity: entity) {
                result.replaceSubrange(fullRange, with: decoded)
            }
        }

        return result
    }

    nonisolated private static func decode(entity: String) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let hex = entity.dropFirst(2)
            guard let scalarValue = UInt32(hex, radix: 16), let scalar = UnicodeScalar(scalarValue) else {
                return nil
            }
            return String(scalar)
        }

        if entity.hasPrefix("#") {
            let decimal = entity.dropFirst(1)
            guard let scalarValue = UInt32(decimal, radix: 10), let scalar = UnicodeScalar(scalarValue) else {
                return nil
            }
            return String(scalar)
        }

        return namedEntities[entity.lowercased()]
    }

    nonisolated private static func normalizeWhitespace(in text: String) -> String {
        let normalizedSpaces = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{1680}", with: " ")
            .replacingOccurrences(of: "\u{2000}", with: " ")
            .replacingOccurrences(of: "\u{2001}", with: " ")
            .replacingOccurrences(of: "\u{2002}", with: " ")
            .replacingOccurrences(of: "\u{2003}", with: " ")
            .replacingOccurrences(of: "\u{2004}", with: " ")
            .replacingOccurrences(of: "\u{2005}", with: " ")
            .replacingOccurrences(of: "\u{2006}", with: " ")
            .replacingOccurrences(of: "\u{2007}", with: " ")
            .replacingOccurrences(of: "\u{2008}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
            .replacingOccurrences(of: "\u{200A}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{205F}", with: " ")
            .replacingOccurrences(of: "\u{3000}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{200C}", with: "")
            .replacingOccurrences(of: "\u{200D}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")

        return normalizedSpaces
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

enum ReaderFacingTextSanitizer {
    nonisolated private static let artifactPatterns = [
        #"\[(影|圖|多圖|影音|影片|相片|照片|photo|video)\]"#,
        #"【(影|圖|多圖|影音|影片|相片|照片|photo|video)】"#,
        #"\((影|圖|多圖|影音|影片|相片|照片|photo|video)\)"#,
        #"（(影|圖|多圖|影音|影片|相片|照片|photo|video)）"#,
        #"'{2,}"#,
        #"["“”‘’]+"#
    ]

    nonisolated private static let sharedPromptMarkers = [
        "assistant:",
        "user:",
        "system:",
        "prompt:",
        "instruction:",
        "instructions:",
        "system prompt",
        "developer prompt",
        "language:",
        "locale:",
        "edition:",
        "設定語言",
        "語系設定",
        "系統語言",
        "システム言語",
        "設定言語",
        "system language",
        "device language",
        "language setting"
    ]

    nonisolated private static let localizedPromptMarkers: [SourceContentLanguage: [String]] = [
        .traditionalChinese: [
            "請使用繁體中文",
            "請用繁體中文",
            "請以繁體中文",
            "請用英文",
            "請用日文",
            "請將以下",
            "依照設定語言",
            "依照系統語言",
            "跟隨系統語言",
            "根據使用者語言",
            "根據裝置語言",
            "提示詞",
            "系統提示",
            "使用者提示"
        ],
        .japanese: [
            "設定言語に合わせて",
            "システム言語に合わせて",
            "日本語で書いて",
            "英語で書いて",
            "繁体中文で書いて",
            "日本語で答えて",
            "英語で答えて",
            "ユーザーの言語設定",
            "デバイスの言語",
            "プロンプト",
            "システムプロンプト",
            "出力形式"
        ],
        .english: [
            "write in traditional chinese",
            "write in japanese",
            "write in english",
            "respond in traditional chinese",
            "respond in japanese",
            "respond in english",
            "answer in traditional chinese",
            "answer in japanese",
            "answer in english",
            "follow the system language",
            "follow the device language",
            "based on the user's locale",
            "based on the user locale",
            "use the same language as",
            "match the app language",
            "match the system language",
            "child-friendly rewrite",
            "rewrite the article"
        ]
    ]

    nonisolated private static let localeTokens = [
        "zh-hant-tw",
        "zh-tw",
        "ja-jp",
        "en-us",
        "traditional chinese",
        "japanese",
        "english",
        "繁體中文",
        "日本語",
        "英文",
        "英語",
        "日文",
        "日語"
    ]

    nonisolated private static let directiveTokens = [
        "respond in",
        "write in",
        "answer in",
        "follow the",
        "依照",
        "跟隨",
        "請用",
        "請以",
        "請使用",
        "書いて",
        "答えて",
        "合わせて"
    ]

    nonisolated static func clean(_ text: String, language: SourceContentLanguage) -> String {
        let normalized = HTMLTextSanitizer.clean(text)
        guard normalized.isEmpty == false else {
            return normalized
        }

        let keptFragments = sentenceFragments(in: normalized).filter { fragment in
            isLikelyPromptLeak(fragment, language: language) == false
        }

        guard keptFragments.isEmpty == false else {
            return ""
        }

        let separator = language == .english ? " " : ""
        let joined = HTMLTextSanitizer.clean(keptFragments.joined(separator: separator))
        return languageSpecificCleanup(joined, language: language)
    }

    nonisolated private static func languageSpecificCleanup(_ text: String, language: SourceContentLanguage) -> String {
        var cleaned = stripArtifacts(in: text)

        switch language {
        case .traditionalChinese:
            cleaned = applyAliases(in: cleaned, aliases: traditionalChineseDisplayAliases)
            cleaned = collapseChineseLatinSpacing(in: cleaned)
            cleaned = collapseDuplicateParentheticalPhrases(in: cleaned)
        case .japanese:
            cleaned = collapseDuplicateParentheticalPhrases(in: cleaned)
        case .english:
            break
        }

        cleaned = cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "，。", with: "。")
            .replacingOccurrences(of: "。。", with: "。")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return HTMLTextSanitizer.clean(cleaned)
    }

    nonisolated private static func stripArtifacts(in text: String) -> String {
        artifactPatterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    nonisolated private static func applyAliases(in text: String, aliases: [String: String]) -> String {
        aliases
            .sorted { $0.key.count > $1.key.count }
            .reduce(text) { partial, entry in
                replaceAlias(entry.key, with: entry.value, in: partial)
            }
    }

    nonisolated private static func replaceAlias(_ key: String, with value: String, in text: String) -> String {
        guard key.isEmpty == false else {
            return text
        }

        if key.canUseLatinWordBoundaryAlias {
            let escaped = NSRegularExpression.escapedPattern(for: key)
            let pattern = "(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
            return text.replacingOccurrences(
                of: pattern,
                with: value,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return text.replacingOccurrences(of: key, with: value)
    }

    nonisolated private static func collapseChineseLatinSpacing(in text: String) -> String {
        text
            .replacingOccurrences(
                of: #"(?<=[\p{Han}])\s+(?=[A-Za-z0-9])"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<=[A-Za-z0-9])\s+(?=[\p{Han}])"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<=[\p{Han}])\s+(?=[\p{Han}])"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<=[\p{Han}])\s+(?=[，。！？；：、])"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<=[，。！？；：、])\s+(?=[\p{Han}])"#,
                with: "",
                options: .regularExpression
            )
    }

    nonisolated private static func collapseDuplicateParentheticalPhrases(in text: String) -> String {
        text.replacingOccurrences(
            of: #"([\p{Han}A-Za-z0-9·・．\-]{2,})\s*[（(]\1[）)]"#,
            with: "$1",
            options: .regularExpression
        )
    }

    nonisolated private static let traditionalChineseDisplayAliases: [String: String] = [
        "Artificial Intelligence": "人工智慧",
        "OpenAI": "OpenAI",
        "ChatGPT": "ChatGPT",
        "World Health Organization": "世界衛生組織",
        "World Meteorological Organization": "世界氣象組織",
        "World Bank": "世界銀行",
        "World Food Programme": "世界糧食計畫署",
        "United Nations": "聯合國",
        "European Union": "歐盟",
        "International Space Station": "國際太空站",
        "National Aeronautics and Space Administration": "美國太空總署",
        "European Space Agency": "歐洲太空總署",
        "National Oceanic and Atmospheric Administration": "美國國家海洋暨大氣總署",
        "Japan Aerospace Exploration Agency": "日本太空機構",
        "Public Broadcasting Service": "美國公共電視",
        "British Broadcasting Corporation": "英國廣播公司",
        "United Nations Educational, Scientific and Cultural Organization": "聯合國教科文組織",
        "United Nations Children's Fund": "聯合國兒童基金會",
        "United Nations Development Programme": "聯合國開發計畫署",
        "International Labour Organization": "國際勞工組織",
        "International Organization for Migration": "國際移民組織",
        "International Atomic Energy Agency": "國際原子能總署",
        "International Committee of the Red Cross": "紅十字國際委員會",
        "Food and Agriculture Organization": "聯合國糧農組織",
        "United Nations Refugee Agency": "聯合國難民署",
        "International Monetary Fund": "國際貨幣基金",
        "Organisation for Economic Co-operation and Development": "經濟合作暨發展組織",
        "Association of Southeast Asian Nations": "東南亞國協",
        "renewable energy": "再生能源",
        "Renewable energy": "再生能源",
        "solar power": "太陽能",
        "Solar power": "太陽能",
        "wind power": "風力發電",
        "Wind power": "風力發電",
        "climate change": "氣候變遷",
        "Climate change": "氣候變遷",
        "greenhouse gas": "溫室氣體",
        "Greenhouse gas": "溫室氣體",
        "greenhouse gases": "溫室氣體",
        "Greenhouse gases": "溫室氣體",
        "biodiversity": "生物多樣性",
        "Biodiversity": "生物多樣性",
        "science": "科學",
        "Science": "科學",
        "technology": "科技",
        "Technology": "科技",
        "scientist": "科學家",
        "Scientist": "科學家",
        "scientists": "科學家",
        "Scientists": "科學家",
        "research": "研究",
        "Research": "研究",
        "researcher": "研究人員",
        "Researcher": "研究人員",
        "researchers": "研究人員",
        "Researchers": "研究人員",
        "laboratory": "實驗室",
        "Laboratory": "實驗室",
        "innovation": "創新",
        "Innovation": "創新",
        "climate crisis": "氣候危機",
        "Climate crisis": "氣候危機",
        "carbon emissions": "碳排放",
        "Carbon emissions": "碳排放",
        "weather": "天氣",
        "Weather": "天氣",
        "coral reef": "珊瑚礁",
        "Coral reef": "珊瑚礁",
        "forest": "森林",
        "Forest": "森林",
        "satellite": "衛星",
        "Satellite": "衛星",
        "satellites": "衛星",
        "Satellites": "衛星",
        "rocket": "火箭",
        "Rocket": "火箭",
        "rockets": "火箭",
        "Rockets": "火箭",
        "spacecraft": "太空船",
        "Spacecraft": "太空船",
        "astronaut": "太空人",
        "Astronaut": "太空人",
        "astronauts": "太空人",
        "Astronauts": "太空人",
        "robot": "機器人",
        "Robot": "機器人",
        "robots": "機器人",
        "Robots": "機器人",
        "vaccine": "疫苗",
        "Vaccine": "疫苗",
        "vaccines": "疫苗",
        "Vaccines": "疫苗",
        "museum": "博物館",
        "Museum": "博物館",
        "library": "圖書館",
        "Library": "圖書館",
        "festival": "節慶",
        "Festival": "節慶",
        "workshop": "工作坊",
        "Workshop": "工作坊",
        "science camp": "科學營",
        "Science camp": "科學營",
        "classroom": "教室",
        "Classroom": "教室",
        "campus": "校園",
        "Campus": "校園",
        "school": "學校",
        "School": "學校",
        "elementary school": "國小",
        "Elementary school": "國小",
        "middle school": "國中",
        "Middle school": "國中",
        "high school": "高中",
        "High school": "高中",
        "kindergarten": "幼兒園",
        "Kindergarten": "幼兒園",
        "preschool": "學前班",
        "Preschool": "學前班",
        "university": "大學",
        "University": "大學",
        "college": "學院",
        "College": "學院",
        "research institute": "研究機構",
        "Research institute": "研究機構",
        "academy": "學院",
        "Academy": "學院",
        "planetarium": "天文館",
        "Planetarium": "天文館",
        "observatory": "天文台",
        "Observatory": "天文台",
        "Ministry of Education": "教育部",
        "Department of Education": "教育局",
        "student": "學生",
        "Student": "學生",
        "students": "學生",
        "Students": "學生",
        "teacher": "老師",
        "Teacher": "老師",
        "teachers": "老師",
        "Teachers": "老師",
        "ocean": "海洋",
        "Ocean": "海洋",
        "planet": "行星",
        "Planet": "行星",
        "wildlife": "野生動物",
        "Wildlife": "野生動物",
        "earthquake": "地震",
        "Earthquake": "地震",
        "volcano": "火山",
        "Volcano": "火山",
        "microplastics": "微塑膠",
        "Microplastics": "微塑膠",
        "moon": "月球",
        "Moon": "月球",
        "Mars": "火星",
        "Pacific Ocean": "太平洋",
        "Arctic": "北極",
        "Antarctica": "南極洲",
        "Hong Kong": "香港",
        "Singapore": "新加坡",
        "United States": "美國",
        "Japan": "日本",
        "Taiwan": "台灣",
        "China": "中國",
        "Ukraine": "烏克蘭",
        "Russia": "俄羅斯",
        "Israel": "以色列",
        "Gaza": "加薩",
        "South Korea": "南韓",
        "North Korea": "北韓",
        "Philippines": "菲律賓",
        "India": "印度",
        "Europe": "歐洲",
        "Asia": "亞洲",
        "Taipei": "台北",
        "Tokyo": "東京",
        "Beijing": "北京",
        "Seoul": "首爾",
        "New York": "紐約",
        "Los Angeles": "洛杉磯",
        "San Francisco": "舊金山",
        "London": "倫敦",
        "Paris": "巴黎",
        "Berlin": "柏林",
        "Rome": "羅馬",
        "Sydney": "雪梨",
        "Washington": "華盛頓",
        "Kyiv": "基輔",
        "Harvard University": "哈佛大學",
        "Massachusetts Institute of Technology": "麻省理工學院",
        "Stanford University": "史丹佛大學",
        "University of Oxford": "牛津大學",
        "University of Cambridge": "劍橋大學",
        "National Taiwan University": "國立台灣大學",
        "University of Tokyo": "東京大學",
        "Kyoto University": "京都大學",
        "Xi Jinping": "習近平",
        "Narendra Modi": "莫迪",
        "Emmanuel Macron": "馬克宏",
        "Pope Francis": "教宗方濟各",
        "Donald Trump": "川普",
        "Joe Biden": "拜登",
        "Volodymyr Zelenskyy": "澤倫斯基",
        "Vladimir Putin": "普丁",
        "Elon Musk": "馬斯克",
        "Sam Altman": "山姆奧特曼",
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
        "WMO": "世界氣象組織",
        "IAEA": "國際原子能總署",
        "WFP": "世界糧食計畫署",
        "ILO": "國際勞工組織",
        "IOM": "國際移民組織",
        "ICRC": "紅十字國際委員會",
        "MIT": "麻省理工學院",
        "STEM": "科學科技工程與數學",
        "GDP": "國內生產毛額",
        "CNA": "中央社",
        "PTS": "公共電視",
        "UN": "聯合國",
        "EU": "歐盟",
        "US": "美國",
        "UK": "英國",
        "ISS": "國際太空站",
        "CO2": "二氧化碳"
    ]

    nonisolated private static func isLikelyPromptLeak(_ fragment: String, language: SourceContentLanguage) -> Bool {
        let normalized = fragment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else {
            return false
        }

        if sharedPromptMarkers.contains(where: normalized.contains) {
            return true
        }

        if localizedPromptMarkers[language, default: []].contains(where: normalized.contains) {
            return true
        }

        let hasLocaleToken = localeTokens.contains(where: normalized.contains)
        let hasDirectiveToken = directiveTokens.contains(where: normalized.contains)
        return hasLocaleToken && hasDirectiveToken
    }

    nonisolated private static func sentenceFragments(in text: String) -> [String] {
        let terminators = CharacterSet(charactersIn: ".!?。！？")
        var fragments: [String] = []
        var current = ""

        for scalar in text.unicodeScalars {
            current.unicodeScalars.append(scalar)
            if terminators.contains(scalar) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    fragments.append(trimmed)
                }
                current.removeAll(keepingCapacity: true)
            }
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if trailing.isEmpty == false {
            fragments.append(trailing)
        }

        return fragments
    }
}

private extension String {
    nonisolated var canUseLatinWordBoundaryAlias: Bool {
        guard isEmpty == false else {
            return false
        }

        return unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            CharacterSet.whitespaces.contains(scalar) ||
            "-.'&,+/".unicodeScalars.contains(scalar)
        }
    }
}

@MainActor
final class DailyNewsCacheStore {
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseURL = cachesURL.appendingPathComponent("JuniorGlobe/LiveNewsCache", isDirectory: true)
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    fileprivate func load(dayKey: String) -> DailyNewsCache? {
        let url = fileURL(for: dayKey)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(DailyNewsCache.self, from: data)
        } catch {
            return nil
        }
    }

    fileprivate func save(_ cache: DailyNewsCache) {
        do {
            try FileManager.default.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(cache)
            try data.write(to: fileURL(for: cache.dayKey), options: .atomic)
            try pruneOldCaches(keepingMostRecent: 7)
        } catch {
            return
        }
    }

    private func fileURL(for dayKey: String) -> URL {
        baseURL.appendingPathComponent("\(dayKey).json")
    }

    private func pruneOldCaches(keepingMostRecent limit: Int) throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted { lhs, rhs in
            lhs.lastPathComponent > rhs.lastPathComponent
        }

        guard urls.count > limit else {
            return
        }

        for url in urls.dropFirst(limit) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private struct OfficialFeedSource: Sendable {
    let id: String
    let source: TrustedSource
    let feedURL: URL
    let allowedMarkets: [AudienceMarket]
    let defaultCategory: StoryCategory?
    let defaultRegion: WorldRegion?
}

private struct CachedLiveStory: Codable, Hashable, Sendable {
    let id: String
    let source: TrustedSource
    let title: String
    let summary: String
    let link: String
    let publishedAt: Date?
    let fetchedAt: Date
    let region: WorldRegion
    let category: StoryCategory
    let marketFocus: [AudienceMarket]
    let safetyNotes: [String]
}

private struct QualifiedCuratedStory: Sendable {
    let story: CuratedStory
    let audienceProfile: StoryAudienceProfile
}

private struct DailyNewsCache: Codable, Sendable {
    let dayKey: String
    var lastRefreshAt: Date?
    var sourceRefreshDates: [String: Date]
    var items: [CachedLiveStory]

    static func empty(dayKey: String) -> DailyNewsCache {
        DailyNewsCache(dayKey: dayKey, lastRefreshAt: nil, sourceRefreshDates: [:], items: [])
    }

    mutating func merge(_ incoming: [CachedLiveStory]) {
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for item in incoming {
            if let existing = byID[item.id], existing.fetchedAt > item.fetchedAt {
                continue
            }

            byID[item.id] = item
        }

        items = Array(byID.values).sorted { lhs, rhs in
            let leftDate = lhs.publishedAt ?? lhs.fetchedAt
            let rightDate = rhs.publishedAt ?? rhs.fetchedAt
            if leftDate != rightDate {
                return leftDate > rightDate
            }

            return lhs.id < rhs.id
        }
    }
}

private struct PremiumRewriteFeedResponse: Decodable, Sendable {
    let generatedAt: Date?
    let source: PremiumRewriteFeedSource
    let stories: [PremiumRewriteStoryPayload]
}

private struct PremiumRewriteFeedSource: Decodable, Sendable {
    let cacheServed: Bool?
    let cacheUpdatedAt: Date?
}

private struct PremiumRewriteStoryPayload: Decodable, Sendable {
    let id: String
    let category: String?
    let region: String?
    let estimatedMinutes: Int?
    let origin: PremiumRewriteOriginPayload
    let localizations: [String: PremiumRewriteLocalizationPayload]
}

private struct PremiumRewriteOriginPayload: Decodable, Sendable {
    let url: String
    let publishedAt: Date?
    let sourceLabel: String?
}

private struct PremiumRewriteLocalizationPayload: Decodable, Sendable {
    let headline: String?
    let deck: String?
    let question: String?
    let whyItMatters: String?
    let sourceLabel: String?
    let versions: [String: PremiumRewriteVersionPayload]
}

private struct PremiumRewriteVersionPayload: Decodable, Sendable {
    let summary: String?
    let highlights: [String]?
}

private struct PremiumRewriteFetchResult: Sendable {
    let stories: [CuratedStory]
    let trustedSources: [TrustedSource]
    let deliveryMode: FeedDeliveryMode
    let lastUpdatedAt: Date?
}

@MainActor
final class LiveCuratedNewsService {
    let editorialPolicy = EditorialPolicy(
        coverageGoals: [
            "只接官方或公共媒體 feed，先用來源白名單降低假新聞風險。",
            "以 UTC 日桶累積同一天抓到的新聞，避免每次開 app 都重新抓全量。",
            "用市場偏好與世界區域平衡排序，減少單一國家或單一主題壟斷版面。"
        ],
        verificationSteps: [
            "只納入官方 HTTPS feed，來源集中為 BBC、PBS、中央社、公視、NHK 與 NASA/JPL。",
            "同一來源在短時間內不重抓；先讀日快取，再依刷新間隔補新內容。",
            "以關鍵字規則先排除血腥、成人、毒品、賭博與仇恨內容，再進入兒少版面。"
        ],
        safetyRules: SafetyRule.allCases
    )

    private let session: URLSession
    private let parser = RSSFeedParser()
    private let cacheStore: DailyNewsCacheStore
    private let premiumRewriteBaseURL: URL?
    private let premiumRewriteBearerToken: String?
    private let premiumRewriteClientID: String
    private let refreshInterval: TimeInterval
    private let now: @Sendable () -> Date

    init(
        session: URLSession = .shared,
        cacheStore: DailyNewsCacheStore? = nil,
        premiumRewriteBaseURL: URL? = AppConfig.premiumRewriteBaseURL,
        premiumRewriteBearerToken: String? = AppConfig.premiumRewriteBearerToken,
        premiumRewriteClientID: String = AppConfig.premiumRewriteClientID,
        refreshInterval: TimeInterval = 20 * 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.cacheStore = cacheStore ?? DailyNewsCacheStore()
        self.premiumRewriteBaseURL = premiumRewriteBaseURL
        self.premiumRewriteBearerToken = premiumRewriteBearerToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.premiumRewriteClientID = premiumRewriteClientID
        self.refreshInterval = refreshInterval
        self.now = now
    }

    func cachedPresentation(
        for edition: AppEdition,
        ageBand: AgeBand,
        includePremium: Bool
    ) async -> NewsFeedPresentation? {
        let dayKey = NewsCacheDayBucket.dayKey(for: now())
        guard let cache = cacheStore.load(dayKey: dayKey), hasCompatibleItems(in: cache, for: edition) else {
            return nil
        }

        return buildPresentation(
            from: cache,
            edition: edition,
            ageBand: ageBand,
            includePremium: includePremium,
            deliveryMode: .cached
        )
    }

    func refreshPresentation(
        for edition: AppEdition,
        ageBand: AgeBand,
        includePremium: Bool,
        forceRefresh: Bool = false
    ) async -> NewsFeedPresentation {
        let currentDate = now()
        let dayKey = NewsCacheDayBucket.dayKey(for: currentDate)
        var cache = cacheStore.load(dayKey: dayKey) ?? DailyNewsCache.empty(dayKey: dayKey)
        let cachedStoryCount = visibleStoryCount(
            in: cache,
            for: edition,
            ageBand: ageBand,
            includePremium: includePremium
        )
        let hasSufficientCoverage = cachedStoryCount >= minimumCoverageTarget(
            for: ageBand,
            includePremium: includePremium
        )

        if
            forceRefresh == false,
            let lastRefreshAt = cache.lastRefreshAt,
            currentDate.timeIntervalSince(lastRefreshAt) < refreshInterval,
            hasSufficientCoverage
        {
            let cachedPresentation = buildPresentation(
                from: cache,
                edition: edition,
                ageBand: ageBand,
                includePremium: includePremium,
                deliveryMode: .cached
            )

            if
                includePremium,
                let premiumPresentation = await premiumRewriteEnrichedPresentation(
                    from: cachedPresentation,
                    edition: edition,
                    ageBand: ageBand
                )
            {
                return premiumPresentation
            }

            return cachedPresentation
        }

        let sources = officialSources(for: edition)
        var didFetchFreshItems = false
        let shouldBypassSourceRefreshInterval = forceRefresh || hasSufficientCoverage == false

        for source in sources {
            if
                shouldBypassSourceRefreshInterval == false,
                let lastSourceRefresh = cache.sourceRefreshDates[source.id],
                currentDate.timeIntervalSince(lastSourceRefresh) < refreshInterval
            {
                continue
            }

            do {
                let items = try await fetchStories(from: source, fetchedAt: currentDate)
                cache.merge(items)
                cache.sourceRefreshDates[source.id] = currentDate
                didFetchFreshItems = didFetchFreshItems || items.isEmpty == false
            } catch {
                continue
            }
        }

        let basePresentation: NewsFeedPresentation

        if hasCompatibleItems(in: cache, for: edition) {
            cache.lastRefreshAt = cache.lastRefreshAt ?? currentDate
            if didFetchFreshItems {
                cache.lastRefreshAt = currentDate
                cacheStore.save(cache)
            }

            basePresentation = buildPresentation(
                from: cache,
                edition: edition,
                ageBand: ageBand,
                includePremium: includePremium,
                deliveryMode: didFetchFreshItems ? .live : .cached
            )
        } else {
            basePresentation = NewsFeedPresentation(
                snapshot: .empty,
                trustedSources: trustedSources(for: edition),
                deliveryMode: .unavailable,
                lastUpdatedAt: nil,
                dayKey: dayKey
            )
        }

        if
            includePremium,
            let premiumPresentation = await premiumRewriteEnrichedPresentation(
                from: basePresentation,
                edition: edition,
                ageBand: ageBand
            )
        {
            return premiumPresentation
        }

        return basePresentation
    }

    private func fetchStories(
        from source: OfficialFeedSource,
        fetchedAt: Date
    ) async throws -> [CachedLiveStory] {
        let (data, response) = try await session.data(from: source.feedURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw RSSFeedParserError.unreadableFeed
        }

        let items = try parser.parse(data: data)

        return items.compactMap { item in
            let cleanedTitle = Self.cleanText(item.title)
            let cleanedSummary = Self.cleanText(item.summary)

            guard NewsSafetyFilter.isSafe(title: cleanedTitle, summary: cleanedSummary) else {
                return nil
            }

            let combinedText = "\(cleanedTitle) \(cleanedSummary)"
            let category = StoryMetadataClassifier.category(
                for: combinedText,
                fallback: source.defaultCategory
            )
            let region = StoryMetadataClassifier.region(
                for: combinedText,
                fallback: source.defaultRegion
            )
            let marketFocus = Array(Set(source.allowedMarkets)).sorted { $0.rawValue < $1.rawValue }

            let stableID = "\(source.id)|\(item.link.lowercased())"

            return CachedLiveStory(
                id: stableID,
                source: source.source,
                title: cleanedTitle,
                summary: cleanedSummary,
                link: item.link,
                publishedAt: item.publishedAt,
                fetchedAt: fetchedAt,
                region: region,
                category: category,
                marketFocus: marketFocus,
                safetyNotes: [
                    "來源為官方 feed",
                    "已套用兒少敏感字詞過濾"
                ]
            )
        }
    }

    private func buildPresentation(
        from cache: DailyNewsCache,
        edition: AppEdition,
        ageBand: AgeBand,
        includePremium: Bool,
        deliveryMode: FeedDeliveryMode
    ) -> NewsFeedPresentation {
        let liveStories = compatibleItems(in: cache, for: edition)
            .map { makeQualifiedStory(from: $0, edition: edition) }
        let premiumLimit = storyLimit(for: ageBand, includePremium: true)
        let freeLimit = storyLimit(for: ageBand, includePremium: false)
        let premiumStories = buildBalancedFeed(
            from: liveStories,
            edition: edition,
            ageBand: ageBand,
            limit: premiumLimit
        )
        .map(\.story)
        .enumerated()
        .map { index, story in
            story.withPremiumOnly(index >= freeLimit)
        }

        let freeStories = Array(premiumStories.prefix(freeLimit))
            .map { $0.withPremiumOnly(false) }

        let visibleStories = includePremium
            ? premiumStories
            : freeStories

        return NewsFeedPresentation(
            snapshot: FeedSnapshot(
                stories: Array(visibleStories),
                lockedStoryCount: includePremium ? 0 : max(0, premiumStories.count - freeStories.count),
                totalAvailableStoryCount: premiumStories.count
            ),
            trustedSources: presentationTrustedSources(for: edition, stories: visibleStories),
            deliveryMode: deliveryMode,
            lastUpdatedAt: cache.lastRefreshAt,
            dayKey: cache.dayKey
        )
    }

    private func premiumRewriteEnrichedPresentation(
        from basePresentation: NewsFeedPresentation,
        edition: AppEdition,
        ageBand: AgeBand
    ) async -> NewsFeedPresentation? {
        let policy = SubscriptionPolicy.current(isPremium: true, ageBand: ageBand)
        let freePolicy = SubscriptionPolicy.current(isPremium: false, ageBand: ageBand)

        guard
            policy.usesPremiumRewriteStories,
            policy.premiumRewriteStoryCount > 0,
            let premiumRewriteBaseURL,
            let premiumRewriteBearerToken,
            premiumRewriteBearerToken.isEmpty == false
        else {
            return nil
        }

        let baseStories = basePresentation.snapshot.stories
        let freeStories = Array(baseStories.prefix(freePolicy.visibleStoryLimit))
            .map { $0.withPremiumOnly(false) }
        let fallbackPremiumStories = Array(baseStories.dropFirst(freePolicy.visibleStoryLimit))
            .map { $0.withPremiumOnly(true) }

        let remoteResult: PremiumRewriteFetchResult?
        do {
            remoteResult = try await fetchPremiumRewriteStories(
                for: edition,
                ageBand: ageBand,
                limit: policy.premiumRewriteStoryCount,
                baseURL: premiumRewriteBaseURL,
                bearerToken: premiumRewriteBearerToken
            )
        } catch {
            remoteResult = nil
        }

        guard let remoteResult, remoteResult.stories.isEmpty == false else {
            return nil
        }

        var premiumStories = freeStories
        premiumStories.append(contentsOf: remoteResult.stories.prefix(policy.premiumRewriteStoryCount))

        if premiumStories.count < policy.visibleStoryLimit {
            let needed = policy.visibleStoryLimit - premiumStories.count
            premiumStories.append(contentsOf: fallbackPremiumStories.prefix(needed))
        }

        premiumStories = Array(premiumStories.prefix(policy.visibleStoryLimit))

        let lastUpdatedAt = [basePresentation.lastUpdatedAt, remoteResult.lastUpdatedAt]
            .compactMap { $0 }
            .max()
        let trustedSources = premiumResultTrustedSources(
            remoteTrustedSources: remoteResult.trustedSources,
            visibleStories: premiumStories,
            market: edition.market
        )

        return NewsFeedPresentation(
            snapshot: FeedSnapshot(
                stories: premiumStories,
                lockedStoryCount: 0,
                totalAvailableStoryCount: max(basePresentation.snapshot.totalAvailableStoryCount, premiumStories.count)
            ),
            trustedSources: trustedSources.isEmpty ? basePresentation.trustedSources : trustedSources,
            deliveryMode: remoteResult.deliveryMode,
            lastUpdatedAt: lastUpdatedAt,
            dayKey: basePresentation.dayKey ?? NewsCacheDayBucket.dayKey(for: now())
        )
    }

    private func fetchPremiumRewriteStories(
        for edition: AppEdition,
        ageBand: AgeBand,
        limit: Int,
        baseURL: URL,
        bearerToken: String
    ) async throws -> PremiumRewriteFetchResult {
        guard let requestURL = premiumRewriteURL(baseURL: baseURL, edition: edition, limit: limit) else {
            throw RSSFeedParserError.unreadableFeed
        }

        var request = URLRequest(url: requestURL)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("premium", forHTTPHeaderField: "X-JuniorGlobe-Entitlement")
        request.setValue("ios", forHTTPHeaderField: "X-JuniorGlobe-Platform")
        request.setValue(premiumRewriteClientID, forHTTPHeaderField: "X-JuniorGlobe-Client")

        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw RSSFeedParserError.unreadableFeed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(PremiumRewriteFeedResponse.self, from: data)

        let stories = payload.stories.compactMap { story in
            makePremiumRewriteStory(from: story, edition: edition, ageBand: ageBand)
        }

        return PremiumRewriteFetchResult(
            stories: Array(stories.prefix(limit)),
            trustedSources: premiumPresentationTrustedSources(for: stories, market: edition.market),
            deliveryMode: payload.source.cacheServed == true ? .cached : .live,
            lastUpdatedAt: payload.source.cacheUpdatedAt ?? payload.generatedAt
        )
    }

    private func premiumRewriteURL(
        baseURL: URL,
        edition: AppEdition,
        limit: Int
    ) -> URL? {
        let endpoint = baseURL.appendingPathComponent("juniorglobe/v1/feed")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "rewrite", value: "full"),
            URLQueryItem(name: "locale", value: premiumRewriteLocaleIdentifier(for: edition))
        ]

        return components.url
    }

    private func makePremiumRewriteStory(
        from payload: PremiumRewriteStoryPayload,
        edition: AppEdition,
        ageBand: AgeBand
    ) -> CuratedStory? {
        guard let localization = premiumRewriteLocalization(from: payload.localizations, edition: edition) else {
            return nil
        }

        let source = premiumRewriteSource(from: payload, localization: localization, edition: edition)
        let combinedText = [
            localization.headline ?? "",
            localization.deck ?? "",
            localization.versions.values.compactMap(\.summary).joined(separator: " ")
        ]
        .joined(separator: " ")

        let category = premiumRewriteCategory(
            rawCategory: payload.category,
            combinedText: combinedText
        )
        let region = premiumRewriteRegion(
            rawRegion: payload.region,
            combinedText: combinedText
        )
        let headline = premiumRewriteHeadline(
            localization: localization,
            category: category,
            region: region,
            edition: edition
        )

        let youngerCopy = premiumRewriteStoryCopy(
            headline: headline,
            localization: localization,
            payload: payload,
            category: category,
            region: region,
            edition: edition,
            ageBand: .ages6to9
        )
        let olderCopy = premiumRewriteStoryCopy(
            headline: headline,
            localization: localization,
            payload: payload,
            category: category,
            region: region,
            edition: edition,
            ageBand: .ages9to12
        )

        let ageCopies = [
            youngerCopy.map { (AgeBand.ages6to9, $0) },
            olderCopy.map { (AgeBand.ages9to12, $0) }
        ]
        .compactMap { $0 }

        guard ageCopies.isEmpty == false else {
            return nil
        }

        return CuratedStory(
            id: "premium-rewrite|\(edition.rawValue)|\(ageBand.rawValue)|\(payload.id)",
            source: source,
            region: region,
            category: category,
            marketFocus: [edition.market],
            premiumOnly: true,
            safetyNotes: [
                "Premium 整理稿",
                "原文仍來自受信任媒體"
            ],
            ageCopies: Dictionary(uniqueKeysWithValues: ageCopies)
        )
    }

    private func premiumRewriteStoryCopy(
        headline: String,
        localization: PremiumRewriteLocalizationPayload,
        payload: PremiumRewriteStoryPayload,
        category: StoryCategory,
        region: WorldRegion,
        edition: AppEdition,
        ageBand: AgeBand
    ) -> StoryCopy? {
        guard let version = premiumRewriteVersion(from: localization.versions, ageBand: ageBand) else {
            return nil
        }

        let summary = premiumRewriteSummary(
            rawSummary: version.summary ?? "",
            rawHeadline: localization.headline ?? headline,
            language: edition.contentLanguage
        )
        guard summary.isEmpty == false else {
            return nil
        }

        let understandingGuide = premiumRewriteUnderstandingGuide(
            highlights: version.highlights ?? [],
            language: edition.contentLanguage
        )
        let backgroundBrief = premiumRewriteBackgroundBrief(
            localization.deck,
            category: category,
            region: region,
            edition: edition,
            ageBand: ageBand
        )
        let whyItMatters = ReaderFacingTextSanitizer.clean(
            localization.whyItMatters ?? "",
            language: edition.contentLanguage
        )
        let talkPrompt = ReaderFacingTextSanitizer.clean(
            localization.question ?? "",
            language: edition.contentLanguage
        )

        return StoryCopy(
            headline: headline,
            summary: summary,
            understandingGuide: understandingGuide,
            backgroundBrief: backgroundBrief,
            whyItMatters: whyItMatters.isEmpty
                ? StoryMetadataClassifier.whyItMatters(for: category, region: region, ageBand: ageBand, edition: edition)
                : whyItMatters,
            talkPrompt: talkPrompt.isEmpty
                ? StoryMetadataClassifier.talkPrompt(for: category, ageBand: ageBand, edition: edition)
                : talkPrompt,
            readingMinutes: max(
                payload.estimatedMinutes ?? 0,
                ageBand == .ages6to9 ? 3 : 4
            )
        )
    }

    private func premiumRewriteLocalization(
        from localizations: [String: PremiumRewriteLocalizationPayload],
        edition: AppEdition
    ) -> PremiumRewriteLocalizationPayload? {
        let preferredKeys: [String]
        switch edition {
        case .taiwanZhHant:
            preferredKeys = ["zh-TW", "zh-Hant-TW", "zh-Hant", "zh"]
        case .japanJa:
            preferredKeys = ["ja-JP", "ja"]
        case .unitedStatesEn:
            preferredKeys = ["en-US", "en"]
        }

        for key in preferredKeys {
            if let localization = localizations[key] {
                return localization
            }
        }

        return localizations.values.first
    }

    private func premiumRewriteVersion(
        from versions: [String: PremiumRewriteVersionPayload],
        ageBand: AgeBand
    ) -> PremiumRewriteVersionPayload? {
        let preferredKeys: [String]
        switch ageBand {
        case .ages6to9:
            preferredKeys = ["ages6to8", "ages9to10", "ages11to12"]
        case .ages9to12:
            preferredKeys = ["ages11to12", "ages9to10", "ages6to8"]
        }

        for key in preferredKeys {
            if let version = versions[key] {
                return version
            }
        }

        return versions.values.first
    }

    private func premiumRewriteSummary(
        rawSummary: String,
        rawHeadline: String,
        language: SourceContentLanguage
    ) -> String {
        var cleaned = ReaderFacingTextSanitizer.clean(rawSummary, language: language)
        let cleanedHeadline = ReaderFacingTextSanitizer.clean(rawHeadline, language: language)

        if cleanedHeadline.isEmpty == false {
            let escapedHeadline = NSRegularExpression.escapedPattern(for: cleanedHeadline)
            cleaned = cleaned.replacingOccurrences(
                of: #"^\#(escapedHeadline)[。．\.:\-–—\s]+"#,
                with: "",
                options: [.regularExpression]
            )
        }

        return ReaderFacingTextSanitizer.clean(cleaned, language: language)
    }

    private func premiumRewriteUnderstandingGuide(
        highlights: [String],
        language: SourceContentLanguage
    ) -> String {
        let cleanedHighlights = highlights
            .map { ReaderFacingTextSanitizer.clean($0, language: language) }
            .filter { $0.isEmpty == false }

        guard cleanedHighlights.isEmpty == false else {
            return ""
        }

        let separator = language == .english ? " " : ""
        return cleanedHighlights.joined(separator: separator)
    }

    private func premiumRewriteBackgroundBrief(
        _ rawDeck: String?,
        category: StoryCategory,
        region: WorldRegion,
        edition: AppEdition,
        ageBand: AgeBand
    ) -> String {
        let cleanedDeck = ReaderFacingTextSanitizer.clean(
            rawDeck ?? "",
            language: edition.contentLanguage
        )

        if cleanedDeck.isEmpty == false {
            return cleanedDeck
        }

        return StoryMetadataClassifier.backgroundBrief(
            for: category,
            region: region,
            ageBand: ageBand,
            edition: edition
        )
    }

    private func premiumRewriteHeadline(
        localization: PremiumRewriteLocalizationPayload,
        category: StoryCategory,
        region: WorldRegion,
        edition: AppEdition
    ) -> String {
        let cleanedHeadline = ReaderFacingTextSanitizer.clean(
            localization.headline ?? "",
            language: edition.contentLanguage
        )

        if premiumRewriteHeadlineLooksLocalized(cleanedHeadline, language: edition.contentLanguage) {
            return cleanedHeadline
        }

        switch edition {
        case .taiwanZhHant:
            return "\(region.label(for: edition))\(category.label(for: edition))整理"
        case .japanJa:
            return "\(region.label(for: edition))の\(category.label(for: edition))ニュース整理"
        case .unitedStatesEn:
            return "\(region.label(for: edition)) \(category.label(for: edition)) Brief"
        }
    }

    private func premiumRewriteHeadlineLooksLocalized(
        _ headline: String,
        language: SourceContentLanguage
    ) -> Bool {
        guard headline.isEmpty == false else {
            return false
        }

        switch language {
        case .traditionalChinese:
            let hanCount = regexMatchCount(#"\p{Han}"#, in: headline)
            let latinCount = regexMatchCount(#"[A-Za-z]"#, in: headline)
            if latinCount == 0 {
                return hanCount > 0
            }
            return hanCount >= max(4, latinCount / 2)
        case .japanese:
            let japaneseCount = regexMatchCount(#"[\p{Han}\p{Hiragana}\p{Katakana}]"#, in: headline)
            let latinCount = regexMatchCount(#"[A-Za-z]"#, in: headline)
            if latinCount == 0 {
                return japaneseCount > 0
            }
            return japaneseCount >= max(4, latinCount / 2)
        case .english:
            return true
        }
    }

    private func regexMatchCount(_ pattern: String, in text: String) -> Int {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: []) else {
            return 0
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.numberOfMatches(in: text, options: [], range: range)
    }

    private func premiumRewriteSource(
        from payload: PremiumRewriteStoryPayload,
        localization: PremiumRewriteLocalizationPayload,
        edition: AppEdition
    ) -> TrustedSource {
        let url = URL(string: payload.origin.url)
        let host = url?.host?.lowercased() ?? ""
        let displayName = localization.sourceLabel ?? payload.origin.sourceLabel ?? host
        let sourceID = "premium-rewrite-\(host.replacingOccurrences(of: ".", with: "-"))"
        let authorityLabel = premiumRewriteAuthorityLabel(host: host, sourceLabel: displayName)
        let countryLabel = premiumRewriteCountryLabel(host: host)

        return TrustedSource(
            id: sourceID,
            name: displayName,
            countryLabel: countryLabel,
            authorityLabel: authorityLabel,
            reasonTrusted: "Premium rewrite service using trusted news sources",
            preferredMarkets: [edition.market]
        )
    }

    private func premiumRewriteAuthorityLabel(host: String, sourceLabel: String) -> String {
        if host.contains("nasa") || host.contains("jpl") {
            return "政府機構"
        }

        if host.contains("reuters") || host.contains("apnews") || host.contains("cnn") || host.contains("theguardian") || host.contains("ft.com") {
            return "國際通訊社"
        }

        if host.contains("cna.com.tw") || host.contains("rti.org.tw") || host.contains("nhk.or.jp") {
            return "國家通訊社"
        }

        if host.contains("pbs.org") || host.contains("npr.org") || host.contains("bbc.") || host.contains("abc.net.au") || host.contains("pts.org.tw") {
            return "公共媒體"
        }

        return sourceLabel.localizedCaseInsensitiveContains("news") ? "國際通訊社" : "公共媒體"
    }

    private func premiumRewriteCountryLabel(host: String) -> String {
        switch host {
        case _ where host.contains("bbc."):
            return "英國 / 全球"
        case _ where host.contains("nhk.or.jp"):
            return "日本"
        case _ where host.contains("cna.com.tw") || host.contains("pts.org.tw") || host.contains("rti.org.tw"):
            return "台灣"
        case _ where host.contains("abc.net.au"):
            return "澳洲"
        case _ where host.contains("reuters.com"), _ where host.contains("theguardian"), _ where host.contains("ft.com"):
            return "英國 / 全球"
        default:
            return "美國"
        }
    }

    private func premiumRewriteCategory(
        rawCategory: String?,
        combinedText: String
    ) -> StoryCategory {
        switch rawCategory?.lowercased() {
        case "science", "space", "health":
            return .science
        case "climate", "environment":
            return .climate
        case "education", "culture", "community":
            return .culture
        case "innovation", "technology":
            return .innovation
        case "world", "public-interest", "major-developments":
            return .civics
        default:
            return StoryMetadataClassifier.category(for: combinedText, fallback: .science)
        }
    }

    private func premiumRewriteRegion(
        rawRegion: String?,
        combinedText: String
    ) -> WorldRegion {
        switch rawRegion?.lowercased() {
        case "northamerica", "north-america":
            return .northAmerica
        case "southamerica", "south-america", "latinamerica", "latin-america":
            return .latinAmerica
        case "europe":
            return .europe
        case "africa":
            return .africa
        case "asiapacific", "asia-pacific", "oceania":
            return .asiaPacific
        case "global", "world":
            return .global
        default:
            return StoryMetadataClassifier.region(for: combinedText, fallback: .global)
        }
    }

    private func premiumPresentationTrustedSources(
        for stories: [CuratedStory],
        market: AudienceMarket
    ) -> [TrustedSource] {
        let uniqueSources = Array(Set(stories.map(\.source)))
        return uniqueSources.sorted { lhs, rhs in
            compareTrustedSources(lhs, rhs, market: market)
        }
    }

    private func premiumResultTrustedSources(
        remoteTrustedSources: [TrustedSource],
        visibleStories: [CuratedStory],
        market: AudienceMarket
    ) -> [TrustedSource] {
        let visibleSourceIDs = Set(visibleStories.map { $0.source.id })
        let remoteMatches = remoteTrustedSources.filter { visibleSourceIDs.contains($0.id) }

        if remoteMatches.isEmpty == false {
            return remoteMatches.sorted { lhs, rhs in
                compareTrustedSources(lhs, rhs, market: market)
            }
        }

        return premiumPresentationTrustedSources(for: visibleStories, market: market)
    }

    private func premiumRewriteLocaleIdentifier(for edition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return "zh-TW"
        case .japanJa:
            return "ja-JP"
        case .unitedStatesEn:
            return "en-US"
        }
    }

    private func makeQualifiedStory(from item: CachedLiveStory, edition: AppEdition) -> QualifiedCuratedStory {
        let story = makeCuratedStory(from: item, edition: edition)
        let audienceProfile = StoryAudienceClassifier.profile(
            title: item.title,
            summary: Self.preferredStorySummary(summary: item.summary, fallbackTitle: item.title),
            category: item.category,
            region: item.region,
            edition: edition
        )

        return QualifiedCuratedStory(story: story, audienceProfile: audienceProfile)
    }

    private func makeCuratedStory(from item: CachedLiveStory, edition: AppEdition) -> CuratedStory {
        let youngerSummary = Self.displayStorySummary(
            summary: item.summary,
            fallbackTitle: item.title,
            edition: edition,
            ageBand: .ages6to9
        )
        let olderSummary = Self.displayStorySummary(
            summary: item.summary,
            fallbackTitle: item.title,
            edition: edition,
            ageBand: .ages9to12
        )

        return CuratedStory(
            id: item.id,
            source: item.source,
            region: item.region,
            category: item.category,
            marketFocus: item.marketFocus,
            premiumOnly: false,
            safetyNotes: item.safetyNotes,
            ageCopies: [
                .ages6to9: StoryCopy(
                    headline: item.title,
                    summary: youngerSummary,
                    understandingGuide: StoryMetadataClassifier.understandingGuide(for: item.category, region: item.region, ageBand: .ages6to9, edition: edition),
                    backgroundBrief: StoryMetadataClassifier.backgroundBrief(for: item.category, region: item.region, ageBand: .ages6to9, edition: edition),
                    whyItMatters: StoryMetadataClassifier.whyItMatters(for: item.category, region: item.region, ageBand: .ages6to9, edition: edition),
                    talkPrompt: StoryMetadataClassifier.talkPrompt(for: item.category, ageBand: .ages6to9, edition: edition),
                    readingMinutes: 3
                ),
                .ages9to12: StoryCopy(
                    headline: item.title,
                    summary: olderSummary,
                    understandingGuide: StoryMetadataClassifier.understandingGuide(for: item.category, region: item.region, ageBand: .ages9to12, edition: edition),
                    backgroundBrief: StoryMetadataClassifier.backgroundBrief(for: item.category, region: item.region, ageBand: .ages9to12, edition: edition),
                    whyItMatters: StoryMetadataClassifier.whyItMatters(for: item.category, region: item.region, ageBand: .ages9to12, edition: edition),
                    talkPrompt: StoryMetadataClassifier.talkPrompt(for: item.category, ageBand: .ages9to12, edition: edition),
                    readingMinutes: 4
                )
            ]
        )
    }

    private func buildBalancedFeed(
        from stories: [QualifiedCuratedStory],
        edition: AppEdition,
        ageBand: AgeBand,
        limit: Int
    ) -> [QualifiedCuratedStory] {
        let market = edition.market
        let eligibleStories = stories.filter { $0.audienceProfile.isAllowed(for: ageBand) }
        let sortedStories = stories.sorted { lhs, rhs in
            let leftScore = storyPriority(lhs.story, market: market, ageBand: ageBand, audienceProfile: lhs.audienceProfile)
            let rightScore = storyPriority(rhs.story, market: market, ageBand: ageBand, audienceProfile: rhs.audienceProfile)

            if leftScore != rightScore {
                return leftScore > rightScore
            }

            return lhs.story.id < rhs.story.id
        }
        let prioritizedStories = eligibleStories.sorted { lhs, rhs in
            let leftScore = storyPriority(lhs.story, market: market, ageBand: ageBand, audienceProfile: lhs.audienceProfile)
            let rightScore = storyPriority(rhs.story, market: market, ageBand: ageBand, audienceProfile: rhs.audienceProfile)

            if leftScore != rightScore {
                return leftScore > rightScore
            }

            return lhs.story.id < rhs.story.id
        }

        var selectedStories: [QualifiedCuratedStory] = []
        var selectedStoryIDs: Set<String> = []
        var seenRegions: Set<WorldRegion> = []
        var seenCategories: Set<StoryCategory> = []
        var seenSources: Set<String> = []

        for story in prioritizedStories where seenRegions.contains(story.story.region) == false {
            selectedStories.append(story)
            selectedStoryIDs.insert(story.story.id)
            seenRegions.insert(story.story.region)
            seenCategories.insert(story.story.category)
            seenSources.insert(story.story.source.id)

            if selectedStories.count == limit {
                return selectedStories
            }
        }

        if ageBand == .ages9to12 {
            for story in prioritizedStories
            where selectedStoryIDs.contains(story.story.id) == false && seenCategories.contains(story.story.category) == false {
                selectedStories.append(story)
                selectedStoryIDs.insert(story.story.id)
                seenCategories.insert(story.story.category)
                seenSources.insert(story.story.source.id)

                if selectedStories.count == limit {
                    return selectedStories
                }
            }

            for story in prioritizedStories
            where selectedStoryIDs.contains(story.story.id) == false && seenSources.contains(story.story.source.id) == false {
                selectedStories.append(story)
                selectedStoryIDs.insert(story.story.id)
                seenSources.insert(story.story.source.id)

                if selectedStories.count == limit {
                    return selectedStories
                }
            }
        }

        let overflowStories = ageBand == .ages6to9 ? prioritizedStories : sortedStories
        for story in overflowStories where selectedStoryIDs.contains(story.story.id) == false {
            selectedStories.append(story)
            selectedStoryIDs.insert(story.story.id)

            if selectedStories.count == limit {
                break
            }
        }

        return selectedStories
    }

    private func storyLimit(for ageBand: AgeBand, includePremium: Bool) -> Int {
        SubscriptionPolicy.current(isPremium: includePremium, ageBand: ageBand).visibleStoryLimit
    }

    private func minimumCoverageTarget(for ageBand: AgeBand, includePremium: Bool) -> Int {
        let limit = storyLimit(for: ageBand, includePremium: includePremium)

        switch ageBand {
        case .ages6to9:
            return min(limit, 4)
        case .ages9to12:
            return min(limit, 6)
        }
    }

    private func visibleStoryCount(
        in cache: DailyNewsCache,
        for edition: AppEdition,
        ageBand: AgeBand,
        includePremium: Bool
    ) -> Int {
        guard hasCompatibleItems(in: cache, for: edition) else {
            return 0
        }

        return buildPresentation(
            from: cache,
            edition: edition,
            ageBand: ageBand,
            includePremium: includePremium,
            deliveryMode: .cached
        )
        .snapshot
        .stories
        .count
    }

    private func storyPriority(
        _ story: CuratedStory,
        market: AudienceMarket,
        ageBand: AgeBand,
        audienceProfile: StoryAudienceProfile
    ) -> Int {
        var score = story.marketFocus.contains(market) ? 5 : 0
        score += story.source.preferredMarkets.contains(market) ? 2 : 1
        score += audienceProfile.priorityBonus(for: ageBand)

        switch (market, story.region) {
        case (.unitedStates, .northAmerica), (.taiwan, .asiaPacific), (.japan, .asiaPacific):
            score += 2
        case (_, .global):
            score += 1
        default:
            break
        }

        switch story.category {
        case .science, .climate:
            score += 1
        default:
            break
        }

        switch ageBand {
        case .ages6to9:
            switch story.category {
            case .science, .climate, .culture:
                score += 2
            case .innovation:
                score += 1
            case .civics:
                if audienceProfile.topicMaturity == .gentle {
                    score += 1
                }
            }
        case .ages9to12:
            switch story.category {
            case .civics, .innovation:
                score += 2
            case .science, .climate:
                score += 1
            case .culture:
                break
            }
        }

        return score
    }

    private func officialSources(for edition: AppEdition) -> [OfficialFeedSource] {
        Self.catalog.filter { source in
            source.allowedMarkets.contains(edition.market) && source.source.isCompatible(with: edition)
        }
    }

    private func trustedSources(for edition: AppEdition) -> [TrustedSource] {
        let market = edition.market
        return Array(Set(officialSources(for: edition).map(\.source))).sorted { lhs, rhs in
            compareTrustedSources(lhs, rhs, market: market)
        }
    }

    private func compatibleItems(in cache: DailyNewsCache, for edition: AppEdition) -> [CachedLiveStory] {
        cache.items.filter { $0.source.isCompatible(with: edition) }
    }

    private func hasCompatibleItems(in cache: DailyNewsCache, for edition: AppEdition) -> Bool {
        compatibleItems(in: cache, for: edition).isEmpty == false
    }

    private func presentationTrustedSources(for edition: AppEdition, stories: [CuratedStory]) -> [TrustedSource] {
        let market = edition.market
        let storySourceIDs = Set(stories.map { $0.source.id })
        let uniqueSources = trustedSources(for: edition)

        return uniqueSources
            .filter { storySourceIDs.contains($0.id) }
            .sorted { lhs, rhs in
                compareTrustedSources(lhs, rhs, market: market)
            }
    }

    private func compareTrustedSources(_ lhs: TrustedSource, _ rhs: TrustedSource, market: AudienceMarket) -> Bool {
        let leftScore = lhs.preferredMarkets.contains(market) ? 1 : 0
        let rightScore = rhs.preferredMarkets.contains(market) ? 1 : 0
        if leftScore != rightScore {
            return leftScore > rightScore
        }

        return lhs.name < rhs.name
    }

    private nonisolated static func cleanText(_ text: String) -> String {
        HTMLTextSanitizer.clean(text)
    }

    nonisolated static func preferredStorySummary(summary: String, fallbackTitle: String) -> String {
        let cleanedSummary = cleanText(summary)
        if cleanedSummary.isEmpty == false {
            return cleanedSummary
        }

        return cleanText(fallbackTitle)
    }

    nonisolated static func displayStorySummary(
        summary: String,
        fallbackTitle: String,
        edition: AppEdition,
        ageBand: AgeBand
    ) -> String {
        let preferredSummary = ReaderFacingTextSanitizer.clean(
            preferredStorySummary(summary: summary, fallbackTitle: fallbackTitle),
            language: edition.contentLanguage
        )

        switch edition {
        case .unitedStatesEn:
            return englishReaderSummary(preferredSummary, ageBand: ageBand)
        case .taiwanZhHant, .japanJa:
            return preferredSummary
        }
    }

    private nonisolated static func englishReaderSummary(_ text: String, ageBand: AgeBand) -> String {
        let sentenceLimit = ageBand == .ages6to9 ? 1 : 2
        let wordLimit = ageBand == .ages6to9 ? 26 : 44
        let normalized = cleanText(text)
        let sentenceBased = splitSentences(in: normalized)
            .prefix(sentenceLimit)
            .joined(separator: " ")

        let candidate = sentenceBased.isEmpty ? normalized : sentenceBased
        if candidate.split(separator: " ").count > wordLimit {
            return trimmedSentence(candidate, wordLimit: wordLimit)
        }

        return ensureSentenceEnding(candidate)
    }

    private nonisolated static func splitSentences(in text: String) -> [String] {
        text
            .replacingOccurrences(of: "!", with: ".")
            .replacingOccurrences(of: "?", with: ".")
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private nonisolated static func trimmedSentence(_ text: String, wordLimit: Int) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > wordLimit else {
            return ensureSentenceEnding(text)
        }

        let trimmed = words.prefix(wordLimit).joined(separator: " ")
        return ensureSentenceEnding(trimmed)
    }

    private nonisolated static func ensureSentenceEnding(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return trimmed
        }

        if [".", "!", "?"].contains(String(trimmed.suffix(1))) {
            return trimmed
        }

        return trimmed + "."
    }

    private static let catalog: [OfficialFeedSource] = [
        OfficialFeedSource(
            id: "bbc-world",
            source: TrustedSource(
                id: "bbc-live",
                name: "BBC News",
                countryLabel: "英國",
                authorityLabel: "公共媒體",
                reasonTrusted: "BBC 提供官方穩定 RSS，屬公共媒體，適合做全球版的基礎國際來源。",
                preferredMarkets: [.unitedStates, .taiwan, .japan]
            ),
            feedURL: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!,
            allowedMarkets: [.unitedStates, .taiwan, .japan],
            defaultCategory: .civics,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "bbc-technology",
            source: TrustedSource(
                id: "bbc-live",
                name: "BBC News",
                countryLabel: "英國",
                authorityLabel: "公共媒體",
                reasonTrusted: "BBC 提供官方穩定 RSS，屬公共媒體，適合做全球版的基礎國際來源。",
                preferredMarkets: [.unitedStates, .taiwan, .japan]
            ),
            feedURL: URL(string: "https://feeds.bbci.co.uk/news/technology/rss.xml")!,
            allowedMarkets: [.unitedStates, .taiwan, .japan],
            defaultCategory: .innovation,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "bbc-science",
            source: TrustedSource(
                id: "bbc-live",
                name: "BBC News",
                countryLabel: "英國",
                authorityLabel: "公共媒體",
                reasonTrusted: "BBC 提供官方穩定 RSS，屬公共媒體，適合做全球版的基礎國際來源。",
                preferredMarkets: [.unitedStates, .taiwan, .japan]
            ),
            feedURL: URL(string: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml")!,
            allowedMarkets: [.unitedStates, .taiwan, .japan],
            defaultCategory: .science,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "cna-intworld",
            source: TrustedSource(
                id: "cna-live",
                name: "中央社",
                countryLabel: "台灣",
                authorityLabel: "國家通訊社",
                reasonTrusted: "中央社公開列出官方 RSS 與使用規範，適合台灣市場的中文國際新聞入口。",
                preferredMarkets: [.taiwan]
            ),
            feedURL: URL(string: "https://feeds.feedburner.com/rsscna/intworld")!,
            allowedMarkets: [.taiwan],
            defaultCategory: .civics,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "cna-technology",
            source: TrustedSource(
                id: "cna-live",
                name: "中央社",
                countryLabel: "台灣",
                authorityLabel: "國家通訊社",
                reasonTrusted: "中央社公開列出官方 RSS 與使用規範，適合台灣市場的中文國際新聞入口。",
                preferredMarkets: [.taiwan]
            ),
            feedURL: URL(string: "https://feeds.feedburner.com/rsscna/technology")!,
            allowedMarkets: [.taiwan],
            defaultCategory: .innovation,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "cna-culture",
            source: TrustedSource(
                id: "cna-live",
                name: "中央社",
                countryLabel: "台灣",
                authorityLabel: "國家通訊社",
                reasonTrusted: "中央社公開列出官方 RSS 與使用規範，適合台灣市場的中文國際新聞入口。",
                preferredMarkets: [.taiwan]
            ),
            feedURL: URL(string: "https://feeds.feedburner.com/rsscna/culture")!,
            allowedMarkets: [.taiwan],
            defaultCategory: .culture,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "cna-lifehealth",
            source: TrustedSource(
                id: "cna-live",
                name: "中央社",
                countryLabel: "台灣",
                authorityLabel: "國家通訊社",
                reasonTrusted: "中央社公開列出官方 RSS 與使用規範，能補進生活與健康面向的兒少可讀真實新聞。",
                preferredMarkets: [.taiwan]
            ),
            feedURL: URL(string: "https://feeds.feedburner.com/rsscna/lifehealth")!,
            allowedMarkets: [.taiwan],
            defaultCategory: .climate,
            defaultRegion: .asiaPacific
        ),
        OfficialFeedSource(
            id: "pts-news",
            source: TrustedSource(
                id: "pts-live",
                name: "公視新聞網",
                countryLabel: "台灣",
                authorityLabel: "公共媒體",
                reasonTrusted: "公視在官方 RSS 服務頁公開新聞 feed，能補足台灣版的公共媒體觀點。",
                preferredMarkets: [.taiwan]
            ),
            feedURL: URL(string: "https://news.pts.org.tw/xml/newsfeed.xml")!,
            allowedMarkets: [.taiwan],
            defaultCategory: .civics,
            defaultRegion: .asiaPacific
        ),
        OfficialFeedSource(
            id: "nhk-general",
            source: TrustedSource(
                id: "nhk-live",
                name: "NHK NEWS WEB",
                countryLabel: "日本",
                authorityLabel: "公共媒體",
                reasonTrusted: "使用 NHK 官方網域上的 XML feed，適合作為日本市場的本地公共媒體來源。",
                preferredMarkets: [.japan]
            ),
            feedURL: URL(string: "https://www3.nhk.or.jp/rss/news/cat0.xml")!,
            allowedMarkets: [.japan],
            defaultCategory: .civics,
            defaultRegion: .asiaPacific
        ),
        OfficialFeedSource(
            id: "nhk-science-medical",
            source: TrustedSource(
                id: "nhk-live",
                name: "NHK NEWS WEB",
                countryLabel: "日本",
                authorityLabel: "公共媒體",
                reasonTrusted: "使用 NHK 官方網域上的 XML feed，適合作為日本市場的本地公共媒體來源。",
                preferredMarkets: [.japan]
            ),
            feedURL: URL(string: "https://www3.nhk.or.jp/rss/news/cat3.xml")!,
            allowedMarkets: [.japan],
            defaultCategory: .science,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "nhk-economy",
            source: TrustedSource(
                id: "nhk-live",
                name: "NHK NEWS WEB",
                countryLabel: "日本",
                authorityLabel: "公共媒體",
                reasonTrusted: "使用 NHK 官方網域上的 XML feed，適合作為日本市場的本地公共媒體來源。",
                preferredMarkets: [.japan]
            ),
            feedURL: URL(string: "https://www3.nhk.or.jp/rss/news/cat5.xml")!,
            allowedMarkets: [.japan],
            defaultCategory: .civics,
            defaultRegion: .asiaPacific
        ),
        OfficialFeedSource(
            id: "nhk-international",
            source: TrustedSource(
                id: "nhk-live",
                name: "NHK NEWS WEB",
                countryLabel: "日本",
                authorityLabel: "公共媒體",
                reasonTrusted: "使用 NHK 官方網域上的 XML feed，適合作為日本市場的本地公共媒體來源。",
                preferredMarkets: [.japan]
            ),
            feedURL: URL(string: "https://www3.nhk.or.jp/rss/news/cat6.xml")!,
            allowedMarkets: [.japan],
            defaultCategory: .civics,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "pbs-headlines",
            source: TrustedSource(
                id: "pbs-live",
                name: "PBS NewsHour",
                countryLabel: "美國",
                authorityLabel: "公共媒體",
                reasonTrusted: "PBS NewsHour 在官方頁面公開 RSS，適合作為美國版的公共媒體國際與公共事務來源。",
                preferredMarkets: [.unitedStates]
            ),
            feedURL: URL(string: "https://www.pbs.org/newshour/feeds/rss/headlines")!,
            allowedMarkets: [.unitedStates],
            defaultCategory: .civics,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "nasa-latest",
            source: TrustedSource(
                id: "nasa-live",
                name: "NASA",
                countryLabel: "美國",
                authorityLabel: "政府機構",
                reasonTrusted: "NASA 官方提供 RSS，適合作為科學與太空類的高可信來源。",
                preferredMarkets: [.unitedStates]
            ),
            feedURL: URL(string: "https://www.nasa.gov/feed/")!,
            allowedMarkets: [.unitedStates],
            defaultCategory: .science,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "nasa-technology",
            source: TrustedSource(
                id: "nasa-live",
                name: "NASA",
                countryLabel: "美國",
                authorityLabel: "政府機構",
                reasonTrusted: "NASA 官方提供 RSS，適合作為科學與太空類的高可信來源。",
                preferredMarkets: [.unitedStates]
            ),
            feedURL: URL(string: "https://www.nasa.gov/technology/feed/")!,
            allowedMarkets: [.unitedStates],
            defaultCategory: .innovation,
            defaultRegion: .global
        ),
        OfficialFeedSource(
            id: "jpl-news",
            source: TrustedSource(
                id: "jpl-live",
                name: "NASA JPL",
                countryLabel: "美國",
                authorityLabel: "政府機構",
                reasonTrusted: "JPL 在官方頁面公開新聞 RSS，能補進太空探索與任務進展的第一手來源。",
                preferredMarkets: [.unitedStates]
            ),
            feedURL: URL(string: "https://www.jpl.nasa.gov/feeds/news/")!,
            allowedMarkets: [.unitedStates],
            defaultCategory: .science,
            defaultRegion: .global
        )
    ]
}

enum StoryMetadataClassifier {
    private static let northAmericaKeywords = [
        "united states", "u.s.", "us ", "usa", "canada", "mexico",
        "美國", "加拿大", "墨西哥", "アメリカ", "カナダ", "メキシコ"
    ]

    private static let latinAmericaKeywords = [
        "brazil", "argentina", "chile", "peru", "colombia", "latin america",
        "巴西", "阿根廷", "智利", "秘魯", "哥倫比亞", "拉丁美洲",
        "ブラジル", "アルゼンチン", "チリ", "ペルー", "コロンビア"
    ]

    private static let europeKeywords = [
        "europe", "uk", "britain", "france", "germany", "italy", "spain", "eu ",
        "歐洲", "英國", "法國", "德國", "義大利", "西班牙",
        "ヨーロッパ", "イギリス", "フランス", "ドイツ", "イタリア", "スペイン"
    ]

    private static let africaKeywords = [
        "africa", "kenya", "nigeria", "sudan", "ethiopia", "uganda",
        "非洲", "肯亞", "奈及利亞", "蘇丹", "衣索比亞", "烏干達",
        "アフリカ", "ケニア", "ナイジェリア", "スーダン", "エチオピア"
    ]

    private static let asiaPacificKeywords = [
        "japan", "taiwan", "china", "korea", "asia", "pacific", "australia", "india",
        "日本", "台灣", "臺灣", "中國", "韓國", "亞洲", "太平洋", "澳洲", "印度",
        "日本", "台湾", "中国", "韓国", "アジア", "太平洋", "オーストラリア", "インド"
    ]

    private static let scienceKeywords = [
        "science", "research", "space", "satellite", "planet", "nasa", "laboratory", "study",
        "科學", "研究", "太空", "衛星", "星球", "實驗室",
        "科学", "研究", "宇宙", "衛星", "惑星", "研究所"
    ]

    private static let climateKeywords = [
        "climate", "weather", "heat", "ocean", "coral", "carbon", "forest", "environment",
        "氣候", "天氣", "高溫", "海洋", "珊瑚", "碳排", "森林", "環境",
        "気候", "天気", "高温", "海洋", "サンゴ", "炭素", "森林", "環境"
    ]

    private static let cultureKeywords = [
        "museum", "festival", "library", "food", "culture", "school exchange", "language",
        "博物館", "節慶", "圖書館", "飲食", "文化", "交流", "語言",
        "博物館", "祭り", "図書館", "食", "文化", "交流", "言語"
    ]

    private static let innovationKeywords = [
        "technology", "robot", "ai", "app", "startup", "chip", "software", "innovation",
        "科技", "機器人", "人工智慧", "晶片", "軟體", "創新",
        "技術", "ロボット", "ai", "半導体", "ソフトウェア", "イノベーション"
    ]

    static func region(for text: String, fallback: WorldRegion?) -> WorldRegion {
        let value = text.lowercased()

        if containsAny(northAmericaKeywords, in: value) {
            return .northAmerica
        }
        if containsAny(latinAmericaKeywords, in: value) {
            return .latinAmerica
        }
        if containsAny(europeKeywords, in: value) {
            return .europe
        }
        if containsAny(africaKeywords, in: value) {
            return .africa
        }
        if containsAny(asiaPacificKeywords, in: value) {
            return .asiaPacific
        }

        return fallback ?? .global
    }

    static func category(for text: String, fallback: StoryCategory?) -> StoryCategory {
        let value = text.lowercased()

        if containsAny(scienceKeywords, in: value) {
            return .science
        }
        if containsAny(climateKeywords, in: value) {
            return .climate
        }
        if containsAny(cultureKeywords, in: value) {
            return .culture
        }
        if containsAny(innovationKeywords, in: value) {
            return .innovation
        }

        return fallback ?? .civics
    }

    static func whyItMatters(
        for category: StoryCategory,
        region: WorldRegion,
        ageBand: AgeBand,
        edition: AppEdition
    ) -> String {
        switch edition {
        case .taiwanZhHant:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "孩子可以知道 \(region.label(for: edition)) 的新發現，常常會影響大家怎麼理解世界。"
            case (.science, .ages9to12):
                return "這類科學新聞能幫孩子把觀察、證據與全球合作放在同一個脈絡裡理解。"
            case (.climate, .ages6to9):
                return "孩子會看到不同地方的人正在想辦法照顧地球和自己的生活。"
            case (.climate, .ages9to12):
                return "這類報導能讓孩子理解氣候議題和日常生活、公共決策其實是連在一起的。"
            case (.culture, .ages6to9):
                return "孩子可以從別人的日常生活裡，學會尊重世界上的不同習慣。"
            case (.culture, .ages9to12):
                return "文化新聞能幫孩子練習比較不同社會的生活方式，而不是只用自己的經驗看世界。"
            case (.innovation, .ages6to9):
                return "孩子會發現科技可以拿來解決真實生活中的問題。"
            case (.innovation, .ages9to12):
                return "孩子能從科技新聞理解創新不是只求新奇，而是怎麼真正改善生活。"
            case (.civics, .ages6to9):
                return "這則新聞讓孩子知道，大家一起合作可以讓社會更安全、更順利。"
            case (.civics, .ages9to12):
                return "這類公民新聞能讓孩子開始理解制度、公共選擇與國際合作的關係。"
            }
        case .japanJa:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "\(region.label(for: edition))で見つかった新しいことは、世界の見え方を変えることがある。"
            case (.science, .ages9to12):
                return "科学ニュースは、観察したことと証拠、そして世界の協力をつなげて考える練習になる。"
            case (.climate, .ages6to9):
                return "いろいろな場所の人が、地球と毎日のくらしを守る工夫をしていることがわかる。"
            case (.climate, .ages9to12):
                return "気候の話は、毎日の生活や公共のルールともつながっていることが見えてくる。"
            case (.culture, .ages6to9):
                return "ちがうくらし方を知ると、世界のいろいろな習慣を大切にできる。"
            case (.culture, .ages9to12):
                return "文化ニュースは、自分の当たり前だけで世界を見ない練習になる。"
            case (.innovation, .ages6to9):
                return "新しい技術は、本当に困っていることを助けるために使えるとわかる。"
            case (.innovation, .ages9to12):
                return "イノベーションは新しいだけでなく、どう生活を良くするかが大切だとわかる。"
            case (.civics, .ages6to9):
                return "みんなで協力すると、社会をもっと安全でくらしやすくできる。"
            case (.civics, .ages9to12):
                return "市民社会のニュースは、制度や公共の選択がどう動くかを考える入口になる。"
            }
        case .unitedStatesEn:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "New discoveries in \(region.label(for: edition)) can change how kids understand the world."
            case (.science, .ages9to12):
                return "Science stories help kids connect observation, evidence, and global teamwork."
            case (.climate, .ages6to9):
                return "Kids can see how people in different places are trying to care for Earth and daily life."
            case (.climate, .ages9to12):
                return "Climate news shows how the environment, daily life, and public choices are connected."
            case (.culture, .ages6to9):
                return "Learning about other routines helps kids respect different ways of living."
            case (.culture, .ages9to12):
                return "Culture stories help kids compare societies without assuming their own experience is the only norm."
            case (.innovation, .ages6to9):
                return "Kids can see that technology can solve real problems people face every day."
            case (.innovation, .ages9to12):
                return "Innovation stories show that progress matters most when it truly improves life."
            case (.civics, .ages6to9):
                return "This story shows kids how working together can make a community safer and smoother."
            case (.civics, .ages9to12):
                return "Civics stories help kids start connecting rules, public choices, and international cooperation."
            }
        }
    }

    static func backgroundBrief(
        for category: StoryCategory,
        region: WorldRegion,
        ageBand: AgeBand,
        edition: AppEdition
    ) -> String {
        switch edition {
        case .taiwanZhHant:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "\(region.label(for: edition)) 最近常出現新的觀測或研究，這則新聞是在告訴我們最新看到什麼。"
            case (.science, .ages9to12):
                return "這類科學議題通常不是一次就能看懂，研究團隊往往會先累積觀測，再慢慢修正解釋。"
            case (.climate, .ages6to9):
                return "\(region.label(for: edition)) 的天氣和環境變化常會連著人們怎麼生活、上學和出門。"
            case (.climate, .ages9to12):
                return "環境新聞背後常牽涉長期觀測、地方生活差異和各地政府怎麼分配資源。"
            case (.culture, .ages6to9):
                return "很多文化新聞都從日常習慣開始，像是吃什麼、怎麼慶祝或怎麼分享故事。"
            case (.culture, .ages9to12):
                return "文化題材通常不是只看表面活動，而是去理解不同社會怎麼形成自己的習慣與價值。"
            case (.innovation, .ages6to9):
                return "新工具和新方法通常是因為有人先發現生活裡有一個問題想解決。"
            case (.innovation, .ages9to12):
                return "創新新聞常和成本、風險、規則以及誰能真正受益有關，不只是技術本身。"
            case (.civics, .ages6to9):
                return "公民新聞常和大家一起遵守規則、互相幫忙，讓生活更安全有關。"
            case (.civics, .ages9to12):
                return "公民議題通常會牽涉制度怎麼設計、不同人怎麼協調，以及公共資源怎麼分配。"
            }
        case .japanJa:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "\(region.label(for: edition))では新しい観測や研究が続いていて、このニュースは最新の発見を伝えている。"
            case (.science, .ages9to12):
                return "科学の話は一度で全部わかるわけではなく、観測を積み重ねながら少しずつ説明が変わっていく。"
            case (.climate, .ages6to9):
                return "\(region.label(for: edition))の天気や環境の変化は、学校やくらし方にもつながっている。"
            case (.climate, .ages9to12):
                return "環境ニュースの背景には、長い観測や地域ごとの生活のちがい、資源の分け方がある。"
            case (.culture, .ages6to9):
                return "文化のニュースは、食べるものやお祝いのしかた、物語の伝え方など、毎日の習慣から始まることが多い。"
            case (.culture, .ages9to12):
                return "文化を知るときは、表に見える行事だけでなく、その社会の価値観や習慣もいっしょに考える。"
            case (.innovation, .ages6to9):
                return "新しい道具や方法は、だれかが生活の困りごとに気づいたところから生まれることが多い。"
            case (.innovation, .ages9to12):
                return "イノベーションのニュースは、技術そのものだけでなく、費用やルール、だれが助かるのかも大切になる。"
            case (.civics, .ages6to9):
                return "市民社会のニュースは、みんなでルールを守ったり助け合ったりして安全にくらす話につながる。"
            case (.civics, .ages9to12):
                return "公の話題には、制度の作り方や意見のちがう人どうしの調整、資源の分け方が関わっている。"
            }
        case .unitedStatesEn:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "\(region.label(for: edition)) has seen new observations and studies, and this story explains the latest thing researchers noticed."
            case (.science, .ages9to12):
                return "Science topics usually become clearer over time as teams collect more observations and adjust their explanations."
            case (.climate, .ages6to9):
                return "Changes in weather and the environment in \(region.label(for: edition)) can shape how people live, learn, and travel."
            case (.climate, .ages9to12):
                return "Environmental stories often connect long-term data, local differences in daily life, and public decisions about resources."
            case (.culture, .ages6to9):
                return "Many culture stories begin with everyday habits, like food, celebrations, and how people share stories."
            case (.culture, .ages9to12):
                return "Culture stories are not only about events on the surface. They also show how values and habits grow in different societies."
            case (.innovation, .ages6to9):
                return "New tools and ideas often begin when someone notices a problem in daily life and wants to solve it."
            case (.innovation, .ages9to12):
                return "Innovation news is about more than the technology itself. Cost, risk, rules, and who benefits all matter too."
            case (.civics, .ages6to9):
                return "Civics stories often connect to rules, teamwork, and ways communities keep life safer."
            case (.civics, .ages9to12):
                return "Civics topics often involve how systems are designed, how people work through disagreements, and how public resources are shared."
            }
        }
    }

    static func understandingGuide(
        for category: StoryCategory,
        region: WorldRegion,
        ageBand: AgeBand,
        edition: AppEdition
    ) -> String {
        switch edition {
        case .taiwanZhHant:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "先記住 \(region.label(for: edition)) 的研究團隊看到了什麼，再想這個新發現會幫大家更懂哪一件事。"
            case (.science, .ages9to12):
                return "可以先分清楚這則新聞說的是觀察結果、研究解釋，還是還需要更多證據的部分，這樣比較不會把猜測當成結論。"
            case (.climate, .ages6to9):
                return "先看環境有什麼變化，再想哪些人的上學、出門或工作會最先受到影響。"
            case (.climate, .ages9to12):
                return "先找出問題發生在哪裡，再比較不同地方要怎麼調整生活和分配資源，會比較容易看懂這則新聞。"
            case (.culture, .ages6to9):
                return "先認識別人怎麼生活、怎麼慶祝，再想這個習慣想傳達什麼心意或價值。"
            case (.culture, .ages9to12):
                return "文化新聞可以先看表面事件，再往下追問它和歷史、價值觀、群體認同有什麼關係。"
            case (.innovation, .ages6to9):
                return "先找到生活裡原本有什麼困難，再看新工具怎麼幫忙，孩子會比較容易理解科技不是只為了酷。"
            case (.innovation, .ages9to12):
                return "這類新聞可以先看問題、再看解法，最後再想成本、風險和誰真正受益，理解會更完整。"
            case (.civics, .ages6to9):
                return "先看大家想一起解決什麼問題，再想規則和合作為什麼能讓生活更安全。"
            case (.civics, .ages9to12):
                return "可以先找出牽涉哪些公共規則和不同立場，再看新聞裡的人怎麼協調，會更容易理解公民題材。"
            }
        case .japanJa:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "まず \(region.label(for: edition)) の研究チームが何を見つけたのかをつかみ、その発見で何がわかりやすくなるのかを考えると読みやすい。"
            case (.science, .ages9to12):
                return "このニュースでは、観測した事実なのか、研究者の説明なのか、まだ確かめている途中なのかを分けて読むと理解しやすい。"
            case (.climate, .ages6to9):
                return "まず環境がどう変わったかを見て、そのあとで学校やくらしにどんな影響が出るのかを考えてみよう。"
            case (.climate, .ages9to12):
                return "問題がどこで起き、だれの生活に関わり、どんな調整が必要になるのかを順番に見ると背景までつながる。"
            case (.culture, .ages6to9):
                return "まず人びとのくらし方やお祝いのしかたを知って、その習慣にどんな気持ちがこめられているかを考えてみよう。"
            case (.culture, .ages9to12):
                return "文化のニュースは、できごとだけでなく、その後ろにある歴史や価値観まで考えると深く読める。"
            case (.innovation, .ages6to9):
                return "最初にどんな困りごとがあったのかを見つけると、新しい道具が何のためにあるのかがわかりやすい。"
            case (.innovation, .ages9to12):
                return "問題、解決方法、その代わりにかかるお金やリスクの順で読むと、技術ニュースをより立体的に理解できる。"
            case (.civics, .ages6to9):
                return "みんなで何をよくしたいのかを先に見つけると、ルールや協力の意味がつかみやすい。"
            case (.civics, .ages9to12):
                return "だれの意見があり、どんなルールが関係し、どこで折り合いをつけるのかを見ると、公の話題が理解しやすくなる。"
            }
        case .unitedStatesEn:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "First notice what researchers in \(region.label(for: edition)) observed, then ask what that new discovery helps people understand better."
            case (.science, .ages9to12):
                return "It helps to separate the observation, the explanation, and the part that still needs more evidence so the story feels clearer."
            case (.climate, .ages6to9):
                return "First look at what changed in the environment, then think about whose school, travel, or daily routine might be affected."
            case (.climate, .ages9to12):
                return "Try reading this story in order: where the problem is happening, who it affects, and what kinds of tradeoffs people may need to make."
            case (.culture, .ages6to9):
                return "Start with what people do in daily life or during a celebration, then think about what feeling or value that habit is trying to share."
            case (.culture, .ages9to12):
                return "Culture stories make more sense when you connect the visible event to history, values, and the group identity behind it."
            case (.innovation, .ages6to9):
                return "First find the everyday problem, then see how the new tool tries to help, and the story becomes much easier to follow."
            case (.innovation, .ages9to12):
                return "A fuller way to read innovation news is to track the problem, the solution, the cost, and who truly benefits."
            case (.civics, .ages6to9):
                return "Look first at the problem people are trying to solve together, then the rules and teamwork start to make more sense."
            case (.civics, .ages9to12):
                return "Civics stories become clearer when you identify the public rules involved, the different viewpoints, and the possible compromise."
            }
        }
    }

    static func talkPrompt(for category: StoryCategory, ageBand: AgeBand, edition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "如果你是小小研究員，你最想觀察什麼現象？"
            case (.science, .ages9to12):
                return "你覺得科學家要說服大家相信新發現，最需要什麼證據？"
            case (.climate, .ages6to9):
                return "你今天可以做哪一件小事來照顧環境？"
            case (.climate, .ages9to12):
                return "你覺得面對環境問題，個人行動和政府政策哪個更重要？"
            case (.culture, .ages6to9):
                return "如果你要介紹自己的城市給外國朋友，你會先帶他看什麼？"
            case (.culture, .ages9to12):
                return "不同地方的習慣不一樣時，你覺得怎麼做才算真正尊重？"
            case (.innovation, .ages6to9):
                return "如果你能發明一個工具，你最想幫誰解決問題？"
            case (.innovation, .ages9to12):
                return "你覺得一個新科技在上線前，最該先考慮什麼風險？"
            case (.civics, .ages6to9):
                return "遇到需要大家一起遵守的規則時，你覺得為什麼合作很重要？"
            case (.civics, .ages9to12):
                return "如果不同人對公共議題看法不同，你覺得應該怎麼討論才公平？"
            }
        case .japanJa:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "もし小さな研究員だったら、どんなことを観察してみたい？"
            case (.science, .ages9to12):
                return "新しい発見を信じてもらうには、どんな証拠がいちばん大切だと思う？"
            case (.climate, .ages6to9):
                return "今日できる、地球にやさしい小さな行動は何だろう？"
            case (.climate, .ages9to12):
                return "環境の問題では、個人の行動と国や町のルールのどちらがより大切だと思う？"
            case (.culture, .ages6to9):
                return "外国の友だちに自分の町を案内するとしたら、まずどこを見せたい？"
            case (.culture, .ages9to12):
                return "習慣がちがう相手を本当に尊重するには、どんなふるまいが必要だと思う？"
            case (.innovation, .ages6to9):
                return "新しい道具を発明できるなら、だれの困りごとを助けたい？"
            case (.innovation, .ages9to12):
                return "新しい技術を広げる前に、どんなリスクを先に考えるべきだと思う？"
            case (.civics, .ages6to9):
                return "みんなで守るルールがあるとき、どうして協力が大切なんだろう？"
            case (.civics, .ages9to12):
                return "公共の問題で意見が分かれたとき、どう話し合うと公平だと思う？"
            }
        case .unitedStatesEn:
            switch (category, ageBand) {
            case (.science, .ages6to9):
                return "If you were a young researcher, what would you want to observe?"
            case (.science, .ages9to12):
                return "What kind of evidence do scientists need most when they want people to trust a new finding?"
            case (.climate, .ages6to9):
                return "What is one small thing you could do today to help the environment?"
            case (.climate, .ages9to12):
                return "When facing an environmental problem, which matters more at first: personal action or public policy?"
            case (.culture, .ages6to9):
                return "If you were showing your city to a friend from another country, where would you take them first?"
            case (.culture, .ages9to12):
                return "When customs are different, what does real respect look like to you?"
            case (.innovation, .ages6to9):
                return "If you could invent a tool, who would you want it to help?"
            case (.innovation, .ages9to12):
                return "Before a new technology goes live, what kind of risk should people think about first?"
            case (.civics, .ages6to9):
                return "Why is teamwork important when everyone needs to follow the same rules?"
            case (.civics, .ages9to12):
                return "If people disagree about a public issue, what would make the discussion feel fair?"
            }
        }
    }

    private static func containsAny(_ keywords: [String], in value: String) -> Bool {
        keywords.contains(where: value.contains)
    }
}

enum StoryReadingLevel: Int, Sendable {
    case emerging
    case developing
    case extending
}

enum StoryTopicMaturity: Int, Sendable {
    case gentle
    case contextual
    case advanced
}

struct StoryAudienceProfile: Sendable {
    let readingLevel: StoryReadingLevel
    let topicMaturity: StoryTopicMaturity

    func isPrimaryFit(for ageBand: AgeBand) -> Bool {
        switch ageBand {
        case .ages6to9:
            return readingLevel == .emerging && topicMaturity == .gentle
        case .ages9to12:
            return readingLevel != .emerging || topicMaturity != .gentle
        }
    }

    func isAllowed(for ageBand: AgeBand) -> Bool {
        switch ageBand {
        case .ages6to9:
            return topicMaturity != .advanced
        case .ages9to12:
            return true
        }
    }

    func priorityBonus(for ageBand: AgeBand) -> Int {
        switch ageBand {
        case .ages6to9:
            if isPrimaryFit(for: ageBand) {
                return 4
            }
            return isAllowed(for: ageBand) ? 1 : -4
        case .ages9to12:
            if isPrimaryFit(for: ageBand) {
                return 4
            }
            return 1
        }
    }
}

enum StoryAudienceClassifier {
    private static let englishAdvancedReadingTerms = [
        "inflation", "tariff", "sanctions", "parliament", "senate", "cabinet", "ministry", "budget",
        "regulation", "diplomatic", "fiscal", "shares", "stocks", "coalition", "ceasefire",
        "constitutional", "semiconductor", "hearing", "commander", "military"
    ]

    private static let japaneseAdvancedReadingTerms = [
        "関税", "停戦", "制裁", "議会", "国会", "政権", "予算", "株価", "金融", "外交",
        "司令官", "防衛", "規制", "法案", "与党", "野党", "半導体"
    ]

    private static let chineseAdvancedReadingTerms = [
        "關稅", "停火", "制裁", "議會", "國會", "政權", "預算", "股價", "金融", "外交",
        "司令官", "國防", "監管", "法案", "政黨", "通膨", "半導體"
    ]

    private static let englishAdvancedTopicTerms = [
        "inflation", "tariff", "sanctions", "parliament", "senate", "budget", "stocks",
        "shares", "ceasefire", "commander", "military", "trade talks", "lawsuit", "court"
    ]

    private static let japaneseAdvancedTopicTerms = [
        "関税", "停戦", "制裁", "国会", "議会", "予算", "株価", "司令官", "外交", "防衛", "法案"
    ]

    private static let chineseAdvancedTopicTerms = [
        "關稅", "停火", "制裁", "國會", "議會", "預算", "股價", "司令官", "外交", "國防", "法案"
    ]

    static func profile(
        title: String,
        summary: String,
        category: StoryCategory,
        region: WorldRegion,
        edition: AppEdition
    ) -> StoryAudienceProfile {
        let text = normalize("\(title) \(summary)")
        let readingLevel = readingLevel(for: text, category: category, language: edition.contentLanguage)
        let topicMaturity = topicMaturity(for: text, category: category, region: region, language: edition.contentLanguage)

        return StoryAudienceProfile(readingLevel: readingLevel, topicMaturity: topicMaturity)
    }

    private static func readingLevel(
        for text: String,
        category: StoryCategory,
        language: SourceContentLanguage
    ) -> StoryReadingLevel {
        var score = 0

        switch language {
        case .english:
            let words = text.split(whereSeparator: \.isWhitespace)
            let longWords = words.filter { $0.count >= 10 }.count
            let advancedHits = keywordHits(in: text, keywords: englishAdvancedReadingTerms)

            if words.count > 30 {
                score += 2
            } else if words.count > 18 {
                score += 1
            }

            if longWords >= 4 || advancedHits >= 2 {
                score += 1
            } else if longWords >= 2 || advancedHits >= 1 {
                score += 1
            }
        case .japanese:
            let characters = visibleCharacterCount(in: text)
            let advancedHits = keywordHits(in: text, keywords: japaneseAdvancedReadingTerms)

            if characters > 80 {
                score += 2
            } else if characters > 42 {
                score += 1
            }

            if advancedHits >= 2 {
                score += 1
            } else if advancedHits >= 1 {
                score += 1
            }
        case .traditionalChinese:
            let characters = visibleCharacterCount(in: text)
            let advancedHits = keywordHits(in: text, keywords: chineseAdvancedReadingTerms)

            if characters > 58 {
                score += 2
            } else if characters > 28 {
                score += 1
            }

            if advancedHits >= 2 {
                score += 1
            } else if advancedHits >= 1 {
                score += 1
            }
        }

        if category == .civics {
            score += 1
        }

        return readingLevel(for: score)
    }

    private static func topicMaturity(
        for text: String,
        category: StoryCategory,
        region: WorldRegion,
        language: SourceContentLanguage
    ) -> StoryTopicMaturity {
        var maturity: StoryTopicMaturity

        switch category {
        case .science, .climate, .culture:
            maturity = .gentle
        case .innovation, .civics:
            maturity = .contextual
        }

        let advancedHits: Int
        switch language {
        case .english:
            advancedHits = keywordHits(in: text, keywords: englishAdvancedTopicTerms)
        case .japanese:
            advancedHits = keywordHits(in: text, keywords: japaneseAdvancedTopicTerms)
        case .traditionalChinese:
            advancedHits = keywordHits(in: text, keywords: chineseAdvancedTopicTerms)
        }

        if advancedHits >= 1 {
            maturity = .advanced
        } else if category == .civics && region == .global {
            maturity = max(maturity, .contextual)
        }

        return maturity
    }

    private static func readingLevel(for score: Int) -> StoryReadingLevel {
        switch min(score, 2) {
        case 0:
            return .emerging
        case 1:
            return .developing
        default:
            return .extending
        }
    }

    private static func max(_ lhs: StoryTopicMaturity, _ rhs: StoryTopicMaturity) -> StoryTopicMaturity {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    private static func keywordHits(in text: String, keywords: [String]) -> Int {
        keywords.reduce(into: 0) { count, keyword in
            if text.contains(keyword) {
                count += 1
            }
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static func visibleCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { count, scalar in
            if CharacterSet.whitespacesAndNewlines.contains(scalar) == false {
                count += 1
            }
        }
    }
}
