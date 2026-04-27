//
//  EditionSettings.swift
//  JuniorGlobe
//

import Foundation

struct EditionPreferenceStore {
    private let userDefaults: UserDefaults
    private let modeKey: String
    private let manualEditionKey: String

    init(
        userDefaults: UserDefaults = .standard,
        namespace: String = "juniorglobe.edition.preference"
    ) {
        self.userDefaults = userDefaults
        self.modeKey = "\(namespace).mode"
        self.manualEditionKey = "\(namespace).manualEdition"
    }

    func load() -> EditionPreference {
        let mode = EditionPreferenceMode(
            rawValue: userDefaults.string(forKey: modeKey) ?? EditionPreferenceMode.system.rawValue
        ) ?? .system

        let manualEdition = userDefaults.string(forKey: manualEditionKey).flatMap(AppEdition.init(rawValue:))
        return EditionPreference(mode: mode, manualEdition: manualEdition)
    }

    func save(_ preference: EditionPreference) {
        userDefaults.set(preference.mode.rawValue, forKey: modeKey)
        userDefaults.set(preference.manualEdition?.rawValue, forKey: manualEditionKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: modeKey)
        userDefaults.removeObject(forKey: manualEditionKey)
    }
}

struct EditionSettings {
    private(set) var preference: EditionPreference
    private(set) var resolvedEdition: AppEdition

    private let store: EditionPreferenceStore
    private let systemLocaleOverride: Locale?

    init(
        store: EditionPreferenceStore? = nil,
        systemLocale: Locale? = nil
    ) {
        let resolvedStore = store ?? EditionPreferenceStore()
        let resolvedSystemLocale = systemLocale ?? Locale.autoupdatingCurrent
        self.store = resolvedStore
        self.systemLocaleOverride = systemLocale

        let loadedPreference = resolvedStore.load()
        self.preference = loadedPreference
        self.resolvedEdition = Self.resolveEdition(for: loadedPreference, systemLocale: resolvedSystemLocale)
    }

    var isFollowingSystem: Bool {
        preference.mode == .system
    }

    mutating func selectManualEdition(_ edition: AppEdition) {
        let updatedPreference = EditionPreference(mode: .manual, manualEdition: edition)
        preference = updatedPreference
        resolvedEdition = edition
        store.save(updatedPreference)
    }

    mutating func followSystem() {
        let updatedPreference = EditionPreference.systemDefault
        preference = updatedPreference
        resolvedEdition = Self.resolveEdition(for: updatedPreference, systemLocale: currentSystemLocale)
        store.save(updatedPreference)
    }

    mutating func refreshResolvedEdition() {
        let nextEdition = Self.resolveEdition(for: preference, systemLocale: currentSystemLocale)
        guard nextEdition != resolvedEdition else {
            return
        }

        resolvedEdition = nextEdition
    }

    private var currentSystemLocale: Locale {
        systemLocaleOverride ?? Locale.autoupdatingCurrent
    }

    private static func resolveEdition(for preference: EditionPreference, systemLocale: Locale) -> AppEdition {
        switch preference.mode {
        case .system:
            return AppEdition.resolve(systemLocale: systemLocale)
        case .manual:
            return preference.manualEdition ?? AppEdition.resolve(systemLocale: systemLocale)
        }
    }
}
