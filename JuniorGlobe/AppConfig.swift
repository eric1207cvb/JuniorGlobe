//
//  AppConfig.swift
//  JuniorGlobe
//

import Foundation

enum AppConfig {
    nonisolated private static let defaultRemoteNarrationBaseURL = "https://wonderkidai-server.onrender.com"

    nonisolated private static func stringConfigValue(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           envValue.isEmpty == false {
            return envValue
        }

        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmedValue = infoValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedValue.isEmpty == false {
                return trimmedValue
            }
        }

        return nil
    }

    nonisolated static var revenueCatAPIKey: String {
        stringConfigValue(for: "JUNIORGLOBE_REVENUECAT_API_KEY") ?? ""
    }

    nonisolated static var premiumRewriteBaseURL: URL? {
        if let configuredURL = stringConfigValue(for: "JUNIORGLOBE_PREMIUM_REWRITE_BASE_URL") {
            let normalized = configuredURL.lowercased()
            if normalized == "disabled" || normalized == "none" || normalized == "off" {
                return nil
            }

            return URL(string: configuredURL)
        }

        if
            let host = stringConfigValue(for: "JUNIORGLOBE_API_HOST"),
            host.isEmpty == false
        {
            let scheme = stringConfigValue(for: "JUNIORGLOBE_API_SCHEME") ?? "https"
            return URL(string: "\(scheme)://\(host)")
        }

        return nil
    }

    nonisolated static var premiumRewriteBearerToken: String? {
        stringConfigValue(for: "JUNIORGLOBE_PREMIUM_REWRITE_BEARER_TOKEN")
    }

    nonisolated static var premiumRewriteClientID: String {
        stringConfigValue(for: "JUNIORGLOBE_PREMIUM_REWRITE_CLIENT_ID") ?? "ios-app"
    }

    nonisolated static var remoteNarrationBaseURL: URL? {
        if let configuredURL = stringConfigValue(for: "JUNIORGLOBE_REMOTE_NARRATION_BASE_URL") {
            let normalized = configuredURL.lowercased()
            if normalized == "disabled" || normalized == "none" || normalized == "off" {
                return nil
            }

            return URL(string: configuredURL)
        }

        if
            let host = stringConfigValue(for: "JUNIORGLOBE_API_HOST"),
            host.isEmpty == false
        {
            let scheme = stringConfigValue(for: "JUNIORGLOBE_API_SCHEME") ?? "https"
            return URL(string: "\(scheme)://\(host)")
        }

        return URL(string: defaultRemoteNarrationBaseURL)
    }

    nonisolated static var japaneseRemoteNarrationVoiceProfile: String {
        switch stringConfigValue(for: "JUNIORGLOBE_JAPANESE_REMOTE_VOICE_AB")?.lowercased() {
        case "b", "cedar":
            return "cedar"
        default:
            return "marin"
        }
    }

    nonisolated static let revenueCatEntitlementID = "premium"
}
