//
//  AppEdition.swift
//  JuniorGlobe
//

import Foundation

enum SourceContentLanguage: String, Codable, Sendable {
    case traditionalChinese
    case japanese
    case english
}

enum HeadlineAnnotationStyle: String, Codable, Sendable {
    case none
    case zhuyin
    case furigana
}

struct EditionReadingSupport: Codable, Sendable {
    let headlineAnnotationStyle: HeadlineAnnotationStyle
    let readAloudEnabled: Bool
}

enum EditionPreferenceMode: String, Codable, Sendable {
    case system
    case manual
}

struct EditionPreference: Codable, Equatable, Sendable {
    let mode: EditionPreferenceMode
    let manualEdition: AppEdition?

    static let systemDefault = EditionPreference(mode: .system, manualEdition: nil)
}

enum AppEdition: String, CaseIterable, Codable, Identifiable, Sendable {
    case taiwanZhHant
    case japanJa
    case unitedStatesEn

    var id: String { rawValue }

    nonisolated var market: AudienceMarket {
        switch self {
        case .taiwanZhHant:
            return .taiwan
        case .japanJa:
            return .japan
        case .unitedStatesEn:
            return .unitedStates
        }
    }

    nonisolated var localeIdentifier: String {
        switch self {
        case .taiwanZhHant:
            return "zh-Hant-TW"
        case .japanJa:
            return "ja-JP"
        case .unitedStatesEn:
            return "en-US"
        }
    }

    nonisolated var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    nonisolated var contentLanguage: SourceContentLanguage {
        switch self {
        case .taiwanZhHant:
            return .traditionalChinese
        case .japanJa:
            return .japanese
        case .unitedStatesEn:
            return .english
        }
    }

    nonisolated var readingSupport: EditionReadingSupport {
        switch self {
        case .taiwanZhHant:
            return EditionReadingSupport(headlineAnnotationStyle: .zhuyin, readAloudEnabled: true)
        case .japanJa:
            return EditionReadingSupport(headlineAnnotationStyle: .furigana, readAloudEnabled: true)
        case .unitedStatesEn:
            return EditionReadingSupport(headlineAnnotationStyle: .none, readAloudEnabled: true)
        }
    }

    nonisolated static func defaultEdition(for market: AudienceMarket) -> AppEdition {
        switch market {
        case .taiwan:
            return .taiwanZhHant
        case .japan:
            return .japanJa
        case .unitedStates:
            return .unitedStatesEn
        }
    }

    nonisolated static func resolve(systemLocale: Locale) -> AppEdition {
        let identifier = systemLocale.identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        if identifier.hasPrefix("ja") || identifier.contains("-jp") {
            return .japanJa
        }

        if identifier.hasPrefix("zh") || identifier.contains("-tw") || identifier.contains("hant") {
            return .taiwanZhHant
        }

        if identifier.hasPrefix("en") || identifier.contains("-us") {
            return .unitedStatesEn
        }

        return .unitedStatesEn
    }
}
