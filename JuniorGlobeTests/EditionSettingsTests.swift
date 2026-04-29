import XCTest
@testable import JuniorGlobe

@MainActor
final class EditionSettingsTests: XCTestCase {
    func testSystemLocaleResolvesToMatchingEdition() {
        XCTAssertEqual(AppEdition.resolve(systemLocale: Locale(identifier: "ja-JP")), .japanJa)
        XCTAssertEqual(AppEdition.resolve(systemLocale: Locale(identifier: "zh-Hant-TW")), .taiwanZhHant)
        XCTAssertEqual(AppEdition.resolve(systemLocale: Locale(identifier: "en-US")), .unitedStatesEn)
    }

    func testManualOverridePersistsAcrossReloads() {
        let store = EditionPreferenceStore(
            userDefaults: .standard,
            namespace: "JuniorGlobeTests.EditionSettings.\(#function)"
        )
        store.clear()
        defer {
            store.clear()
        }
        var settings = EditionSettings(
            store: store,
            systemLocale: Locale(identifier: "en-US")
        )

        settings.selectManualEdition(.japanJa)

        let reloaded = EditionSettings(
            store: store,
            systemLocale: Locale(identifier: "en-US")
        )

        XCTAssertEqual(reloaded.preference.mode, .manual)
        XCTAssertEqual(reloaded.preference.manualEdition, .japanJa)
        XCTAssertEqual(reloaded.resolvedEdition, .japanJa)
    }

    func testFollowSystemClearsManualOverride() {
        let store = EditionPreferenceStore(
            userDefaults: .standard,
            namespace: "JuniorGlobeTests.EditionSettings.\(#function)"
        )
        store.clear()
        defer {
            store.clear()
        }
        var settings = EditionSettings(
            store: store,
            systemLocale: Locale(identifier: "ja-JP")
        )

        settings.selectManualEdition(.unitedStatesEn)
        settings.followSystem()

        let reloaded = EditionSettings(
            store: store,
            systemLocale: Locale(identifier: "ja-JP")
        )

        XCTAssertEqual(reloaded.preference.mode, .system)
        XCTAssertNil(reloaded.preference.manualEdition)
        XCTAssertEqual(reloaded.resolvedEdition, .japanJa)
    }

    func testMonthlySubscriptionPackageUsesEditionLocalizedCopy() {
        let package = SubscriptionPackage(
            id: "juniorglobe.premium.monthly",
            productIdentifier: "juniorglobe.premium.monthly",
            title: "Fallback Title",
            subtitle: "Fallback Subtitle",
            priceLabel: "$3.99"
        )

        XCTAssertEqual(
            AppEdition.taiwanZhHant.strings.subscriptionPackageTitle(for: package),
            "JuniorGlobe Premium 月費版"
        )
        XCTAssertEqual(
            AppEdition.japanJa.strings.subscriptionPackageSubtitle(for: package),
            "6-9歳と9-12歳向けの完全版に加え、背景・流れ・要点整理まで読めます。"
        )
        XCTAssertEqual(
            AppEdition.unitedStatesEn.strings.subscriptionPackageTitle(for: package),
            "JuniorGlobe Premium Monthly"
        )
    }

    func testLegalDocumentsExposeOfficialLinksForAllEditions() {
        for edition in [AppEdition.taiwanZhHant, .japanJa, .unitedStatesEn] {
            let strings = edition.strings

            XCTAssertFalse(strings.legalPrivacyTitle.isEmpty)
            XCTAssertEqual(strings.legalDocuments.count, 3)

            let allLinks = strings.legalDocuments.flatMap(\.links).map(\.urlString)
            XCTAssertTrue(allLinks.contains("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"))
            XCTAssertTrue(allLinks.contains("https://developer.apple.com/app-store/app-privacy-details/"))
            XCTAssertTrue(allLinks.contains("https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa"))
        }
    }

    func testParentGatePromptExistsForAllEditions() {
        let challenge = ParentGateChallenge(firstNumber: 18, secondNumber: 7, operation: .addition)

        XCTAssertEqual(AppEdition.taiwanZhHant.strings.parentGateFallbackPrompt(challenge), "18 + 7 = ?")
        XCTAssertEqual(AppEdition.japanJa.strings.parentGateFallbackPrompt(challenge), "18 + 7 = ?")
        XCTAssertEqual(AppEdition.unitedStatesEn.strings.parentGateFallbackPrompt(challenge), "18 + 7 = ?")
    }

    func testParentGateAcceptsAsciiAndFullWidthDigits() {
        let challenge = ParentGateChallenge(firstNumber: 18, secondNumber: 7, operation: .addition)

        XCTAssertTrue(challenge.matchesAnswer("25"))
        XCTAssertTrue(challenge.matchesAnswer(" ２５ "))
        XCTAssertFalse(challenge.matchesAnswer("26"))
        XCTAssertFalse(challenge.matchesAnswer("二十五"))
    }

    func testParentGateProtectedCopyExistsForAllEditions() {
        for edition in AppEdition.allCases {
            let strings = edition.strings

            XCTAssertFalse(strings.parentGateLockedDetail.isEmpty)
            XCTAssertFalse(strings.parentGateUnlockedDetail.isEmpty)
            XCTAssertEqual(strings.parentGateProtectedItems.count, 4)
            XCTAssertFalse(strings.parentGateAuthenticatingLabel.isEmpty)
            XCTAssertFalse(strings.parentGateCanceledLabel.isEmpty)
            XCTAssertFalse(strings.parentGateRestoreHiddenLabel.isEmpty)
            XCTAssertFalse(strings.parentGateWeeklyReportHiddenLabel.isEmpty)
            XCTAssertFalse(strings.parentGateLinksHiddenLabel.isEmpty)
        }
    }
}

final class StoryNarrationControllerTests: XCTestCase {
    private func withTemporaryEnvironmentValue(
        _ value: String?,
        forKey key: String,
        perform: () -> Void
    ) {
        let previousValue = ProcessInfo.processInfo.environment[key]
        if let value {
            setenv(key, value, 1)
        } else {
            unsetenv(key)
        }

        defer {
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }

        perform()
    }

    func testNarrationStringsUseRetryLabelAfterFailure() {
        let strings = AppEdition.taiwanZhHant.strings
        let failedStatus = StoryNarrationStatus(
            requestID: "story-1",
            stage: .failed(.generationFailed),
            progress: nil
        )

        XCTAssertEqual(strings.narrationButtonTitle(for: failedStatus), "重新生成語音")
        XCTAssertEqual(
            strings.narrationFailureRecoveryHint(for: .timedOut),
            "點一下重新生成語音，通常下一次會更快完成。"
        )
    }

    @MainActor
    func testEnglishSentenceTokenizerKeepsAbbreviationsTogether() {
        let sentences = StoryNarrationController.sentences(
            in: "The U.S. rover landed safely. Kids cheered at school.",
            edition: .unitedStatesEn,
            segment: .summary
        )

        XCTAssertEqual(
            sentences.map(\.text),
            [
                "The U.S. rover landed safely.",
                "Kids cheered at school."
            ]
        )
    }

    @MainActor
    func testTraditionalChineseSentenceTokenizerPreservesNaturalBreaks() {
        let sentences = StoryNarrationController.sentences(
            in: "火箭順利升空。小朋友在教室一起觀看直播！",
            edition: .taiwanZhHant,
            segment: .summary
        )

        XCTAssertEqual(
            sentences.map(\.text),
            [
                "火箭順利升空。",
                "小朋友在教室一起觀看直播！"
            ]
        )
    }

    @MainActor
    func testTraditionalChineseSpokenFragmentsSplitEmbeddedEnglishAndNormalizeSymbols() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "NASA與台灣AI團隊合作（2026）/ BBC直播。",
            language: .traditionalChinese
        )

        XCTAssertEqual(
            fragments,
            [
                "美國太空總署",
                "與台灣",
                "人工智慧",
                "團隊合作，2026，或",
                "英國廣播公司",
                "直播。"
            ]
        )
    }

    @MainActor
    func testJapaneseSpokenFragmentsSplitEmbeddedEnglishAndNormalizeSymbols() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "NHKとAI研究チームがJAXAで発表（きょう）&ライブ配信。",
            language: .japanese
        )

        XCTAssertEqual(
            fragments,
            [
                "エヌエイチケー",
                "と",
                "エーアイ",
                "研究チームが",
                "ジャクサ",
                "で発表、きょう、とライブ配信。"
            ]
        )
    }

    @MainActor
    func testEnglishSpokenFragmentsNormalizeFullWidthPunctuationAndSymbols() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Mars，science＆kids（live）50% update！",
            language: .english
        )

        XCTAssertEqual(
            fragments,
            [
                "Mars, science and kids, live, 50 percent update!"
            ]
        )
    }

    @MainActor
    func testEnglishPhraseAliasesBlendForeignProperNounsIntoEnglishNarration() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Taiwan teams shared 二氧化碳 findings with 日本 partners at the 聯合國.",
            language: .english
        )

        XCTAssertEqual(
            fragments,
            [
                "Taiwan teams shared carbon dioxide findings with Japan partners at the United Nations."
            ]
        )
    }

    @MainActor
    func testTraditionalChineseSpokenFragmentsLocalizeGlobalAcronymsSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "WHO與UNESCO推動STEM計畫。",
            language: .traditionalChinese
        )

        XCTAssertEqual(
            fragments,
            [
                "世界衛生組織",
                "與",
                "聯合國教科文組織",
                "推動",
                "科學科技工程與數學",
                "計畫。"
            ]
        )
    }

    @MainActor
    func testTraditionalChineseSpokenFragmentsHandleSingleLettersAndFullWidthLettersSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Ｃ小調的c和k他命的K都要自然讀出來。",
            language: .traditionalChinese
        )

        XCTAssertEqual(
            fragments,
            [
                "C",
                "小調的",
                "C",
                "和",
                "K",
                "他命的",
                "K",
                "都要自然讀出來。"
            ]
        )
    }

    @MainActor
    func testTraditionalChineseSpokenFragmentsKeepGoogleAsAWord() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Google和AI一起幫忙整理新聞。",
            language: .traditionalChinese
        )

        XCTAssertEqual(
            fragments,
            [
                "Google",
                "和",
                "人工智慧",
                "一起幫忙整理新聞。"
            ]
        )
    }

    @MainActor
    func testTraditionalChineseSpokenFragmentsLocalizeBrandsAndNewsroomsSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Reuters和Bloomberg在Los Angeles報導LEGO與Nintendo新聞。",
            language: .traditionalChinese
        )

        XCTAssertEqual(
            fragments,
            [
                "路透社和彭博在洛杉磯報導樂高與任天堂新聞。"
            ]
        )
    }

    @MainActor
    func testTraditionalChinesePhraseAliasesBlendCitiesAndPeopleSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Donald Trump在New York和Taipei分享太空新聞。",
            language: .traditionalChinese
        )

        XCTAssertEqual(
            fragments,
            [
                "川普在紐約和台北分享太空新聞。"
            ]
        )
    }

    @MainActor
    func testJapaneseSpokenFragmentsLocalizeGlobalAcronymsSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "NASAとWHOがG7で発表。",
            language: .japanese
        )

        XCTAssertEqual(
            fragments,
            [
                "ナサ",
                "と",
                "世界保健機関",
                "が",
                "ジーセブン",
                "で発表。"
            ]
        )
    }

    @MainActor
    func testJapaneseSpokenFragmentsHandleSingleLettersAndFullWidthLettersSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Ｃ調とkビタミンのKも自然に読ませたい。",
            language: .japanese
        )

        XCTAssertEqual(
            fragments,
            [
                "シー",
                "調と",
                "ケー",
                "ビタミンの",
                "ケー",
                "も自然に読ませたい。"
            ]
        )
    }

    @MainActor
    func testJapaneseSpokenFragmentsLocalizeBrandsAndNewsroomsSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "GoogleとReutersがLEGOイベントをLos Angelesで紹介。",
            language: .japanese
        )

        XCTAssertEqual(
            fragments,
            [
                "グーグルとロイターがレゴイベントをロサンゼルスで紹介。"
            ]
        )
    }

    @MainActor
    func testJapanesePhraseAliasesBlendCitiesAndPeopleSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "Joe BidenがTokyoとKyivの子どもニュースを紹介。",
            language: .japanese
        )

        XCTAssertEqual(
            fragments,
            [
                "バイデン大統領が東京とキーウの子どもニュースを紹介。"
            ]
        )
    }

    @MainActor
    func testEnglishPhraseAliasesLocalizeChineseAndJapaneseOrganizationsSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "世界衛生組織 and 聯合國兒童基金會 shared updates with 日本 teams.",
            language: .english
        )

        XCTAssertEqual(
            fragments,
            [
                "World Health Organization and UNICEF shared updates with Japan teams."
            ]
        )
    }

    @MainActor
    func testEnglishPhraseAliasesBlendCitiesAndPeopleSmoothly() {
        let fragments = StoryNarrationController.spokenFragments(
            from: "日本 reporters met 馬斯克 in 台北 after the science event.",
            language: .english
        )

        XCTAssertEqual(
            fragments,
            [
                "Japan reporters met Elon Musk in Taipei after the science event."
            ]
        )
    }

    @MainActor
    func testRemoteSpeechRequestBuildsLocalizedTranscriptSegments() {
        let request = StoryNarrationRequest(
            id: "story-1",
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            headline: "NASA與AI團隊合作。",
            summary: "孩子一起看BBC直播。",
            backgroundBrief: "孩子了解WHO怎麼幫忙。"
        )

        let payload = StoryNarrationController.remoteJobRequest(for: request)
        let segments = StoryNarrationController.remoteNarrationSegments(for: request)

        XCTAssertEqual(payload.model, "gpt-4o-mini-tts")
        XCTAssertEqual(payload.voice, "marin")
        XCTAssertEqual(payload.responseFormat, "mp3")
        XCTAssertEqual(payload.speed, 0.99)
        XCTAssertNotNil(payload.instructions)
        XCTAssertTrue(payload.instructions?.contains("contemporary Taiwan Mandarin") == true)
        XCTAssertTrue(payload.instructions?.contains("elementary teachers in Taiwan") == true)
        XCTAssertTrue(payload.instructions?.contains("local to Taiwan") == true)
        XCTAssertTrue(payload.instructions?.contains("robotic pacing") == true)
        XCTAssertTrue(payload.input.contains("美國太空總署與人工智慧團隊合作。"))
        XCTAssertTrue(payload.input.contains("孩子一起看英國廣播公司直播。"))
        XCTAssertTrue(payload.input.contains("孩子了解世界衛生組織怎麼幫忙。"))
        XCTAssertEqual(segments.map(\.segment), [.headline, .summary, .backgroundBrief])
        XCTAssertEqual(segments[0].sentences[0].text, "美國太空總署與人工智慧團隊合作。")
        XCTAssertEqual(segments[1].sentences[0].text, "孩子一起看英國廣播公司直播。")
        XCTAssertEqual(segments[2].sentences[0].text, "孩子了解世界衛生組織怎麼幫忙。")
    }

    @MainActor
    func testRemoteNarrationCacheKeyIgnoresViewSpecificRequestIDs() {
        let feedRequest = StoryNarrationRequest(
            id: "feed|zh-Hant-TW|ages6to9|story-42",
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            headline: "NASA與AI團隊合作。",
            summary: "孩子一起看BBC直播。",
            backgroundBrief: "孩子了解WHO怎麼幫忙。"
        )
        let favoriteRequest = StoryNarrationRequest(
            id: "favorite|zh-Hant-TW|ages6to9|story-42",
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            headline: "NASA與AI團隊合作。",
            summary: "孩子一起看BBC直播。",
            backgroundBrief: "孩子了解WHO怎麼幫忙。"
        )

        XCTAssertEqual(
            StoryNarrationController.remoteNarrationCacheKey(for: feedRequest),
            StoryNarrationController.remoteNarrationCacheKey(for: favoriteRequest)
        )
    }

    @MainActor
    func testRemoteNarrationCacheKeyChangesWhenNarrationVariantChanges() {
        let youngerRequest = StoryNarrationRequest(
            id: "story-zh-6-9",
            edition: .taiwanZhHant,
            ageBand: .ages6to9,
            headline: "孩子閱讀全球新聞。",
            summary: "老師帶著大家比較不同觀點。",
            backgroundBrief: "先理解今天的重要背景。"
        )
        let olderRequest = StoryNarrationRequest(
            id: "story-zh-9-12",
            edition: .taiwanZhHant,
            ageBand: .ages9to12,
            headline: "孩子閱讀全球新聞。",
            summary: "老師帶著大家比較不同觀點。",
            backgroundBrief: "先理解今天的重要背景。"
        )

        XCTAssertNotEqual(
            StoryNarrationController.remoteNarrationCacheKey(for: youngerRequest),
            StoryNarrationController.remoteNarrationCacheKey(for: olderRequest)
        )
    }

    @MainActor
    func testJapaneseRemoteVoiceSupportsABSelection() {
        let request = StoryNarrationRequest(
            id: "story-ja-ab",
            edition: .japanJa,
            ageBand: .ages9to12,
            headline: "子ども記者が世界ニュースをまとめる。",
            summary: "読み比べながら背景を考える。",
            backgroundBrief: nil
        )

        withTemporaryEnvironmentValue(nil, forKey: "JUNIORGLOBE_JAPANESE_REMOTE_VOICE_AB") {
            let payload = StoryNarrationController.remoteJobRequest(for: request)
            XCTAssertEqual(payload.voice, "marin")
        }

        withTemporaryEnvironmentValue("b", forKey: "JUNIORGLOBE_JAPANESE_REMOTE_VOICE_AB") {
            let payload = StoryNarrationController.remoteJobRequest(for: request)
            XCTAssertEqual(payload.voice, "cedar")
        }
    }

    @MainActor
    func testRemoteSpeechRequestAdjustsPacingByEditionAndAgeBand() {
        let youngerEnglishRequest = StoryNarrationRequest(
            id: "story-en-1",
            edition: .unitedStatesEn,
            ageBand: .ages6to9,
            headline: "Kids watch a Mars launch.",
            summary: "Students cheer in class.",
            backgroundBrief: nil
        )
        let olderEnglishRequest = StoryNarrationRequest(
            id: "story-en-2",
            edition: .unitedStatesEn,
            ageBand: .ages9to12,
            headline: "Students compare science reports.",
            summary: "They discuss why the mission matters.",
            backgroundBrief: nil
        )
        let japaneseRequest = StoryNarrationRequest(
            id: "story-ja-1",
            edition: .japanJa,
            ageBand: .ages6to9,
            headline: "子どもたちが宇宙ニュースを読む。",
            summary: "先生と一緒に意味を確かめる。",
            backgroundBrief: nil
        )

        let youngerEnglishPayload = StoryNarrationController.remoteJobRequest(for: youngerEnglishRequest)
        let olderEnglishPayload = StoryNarrationController.remoteJobRequest(for: olderEnglishRequest)
        let japanesePayload = StoryNarrationController.remoteJobRequest(for: japaneseRequest)
        let olderJapanesePayload = StoryNarrationController.remoteJobRequest(
            for: StoryNarrationRequest(
                id: "story-ja-2",
                edition: .japanJa,
                ageBand: .ages9to12,
                headline: "子ども記者が世界ニュースをまとめる。",
                summary: "読み比べながら背景を考える。",
                backgroundBrief: nil
            )
        )
        let olderTraditionalChinesePayload = StoryNarrationController.remoteJobRequest(
            for: StoryNarrationRequest(
                id: "story-zh-2",
                edition: .taiwanZhHant,
                ageBand: .ages9to12,
                headline: "孩子閱讀全球新聞。",
                summary: "老師帶著大家比較不同觀點。",
                backgroundBrief: nil
            )
        )

        XCTAssertEqual(youngerEnglishPayload.speed, 0.93)
        XCTAssertEqual(olderEnglishPayload.speed, 0.99)
        XCTAssertEqual(japanesePayload.speed, 0.97)
        XCTAssertEqual(olderJapanesePayload.speed, 1.0)
        XCTAssertEqual(olderTraditionalChinesePayload.speed, 1.01)
        XCTAssertEqual(youngerEnglishPayload.voice, "shimmer")
        XCTAssertEqual(olderEnglishPayload.voice, "marin")
        XCTAssertEqual(japanesePayload.voice, "marin")
        XCTAssertEqual(olderJapanesePayload.voice, "marin")
        XCTAssertEqual(olderTraditionalChinesePayload.voice, "marin")
        XCTAssertTrue(youngerEnglishPayload.instructions?.contains("female-presenting voice") == true)
        XCTAssertTrue(youngerEnglishPayload.instructions?.contains("kind teacher reading a story aloud") == true)
        XCTAssertTrue(youngerEnglishPayload.instructions?.contains("choppy or jagged digital tone") == true)
        XCTAssertTrue(japanesePayload.instructions?.contains("standard modern Japanese") == true)
        XCTAssertTrue(japanesePayload.instructions?.contains("elementary teachers in Japan") == true)
        XCTAssertTrue(japanesePayload.instructions?.contains("Tokyo-style standard Japanese") == true)
        XCTAssertTrue(olderJapanesePayload.instructions?.contains("youth news hosts in Japan") == true)
        XCTAssertTrue(olderEnglishPayload.instructions?.contains("youth news presenter") == true)
        XCTAssertTrue(olderEnglishPayload.instructions?.contains("choppy or jagged digital tone") == true)
        XCTAssertTrue(olderTraditionalChinesePayload.instructions?.contains("youth news hosts in Taiwan") == true)
    }
}

final class ParentGateChallengeTests: XCTestCase {
    func testParentGateChallengeCalculatesAdditionAndSubtractionAnswers() {
        let addition = ParentGateChallenge(firstNumber: 18, secondNumber: 7, operation: .addition)
        let subtraction = ParentGateChallenge(firstNumber: 18, secondNumber: 7, operation: .subtraction)

        XCTAssertEqual(addition.answer, 25)
        XCTAssertEqual(subtraction.answer, 11)
    }

    func testGeneratedParentGateChallengesStayWithinChildSafeMathRange() {
        for _ in 0..<200 {
            let challenge = ParentGateChallenge.generate()
            XCTAssertGreaterThanOrEqual(challenge.firstNumber, 12)
            XCTAssertGreaterThanOrEqual(challenge.secondNumber, 3)
            XCTAssertGreaterThanOrEqual(challenge.answer, 0)
        }
    }
}
