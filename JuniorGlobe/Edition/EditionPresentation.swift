//
//  EditionPresentation.swift
//  JuniorGlobe
//

import Foundation
import SwiftUI

struct EditionPalette {
    let heroColors: [Color]
    let lightBackgroundColors: [Color]
    let darkBackgroundColors: [Color]
    let accent: Color
    let secondaryAccent: Color
}

struct LegalDocumentLink: Identifiable, Hashable {
    let title: String
    let urlString: String

    var id: String {
        "\(title)|\(urlString)"
    }
}

struct LegalDocumentSectionContent: Identifiable, Hashable {
    let title: String
    let paragraphs: [String]

    var id: String {
        title
    }
}

struct LegalDocumentContent: Identifiable, Hashable {
    let title: String
    let introduction: String
    let sections: [LegalDocumentSectionContent]
    let links: [LegalDocumentLink]

    var id: String {
        title
    }
}

struct EditionStrings {
    let edition: AppEdition

    var settingsLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "設定"
        case .japanJa:
            return "設定"
        case .unitedStatesEn:
            return "Settings"
        }
    }

    var heroTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "給孩子的全球新聞"
        case .japanJa:
            return "子どものための世界ニュース"
        case .unitedStatesEn:
            return "World News for Kids"
        }
    }

    var heroSubtitle: String {
        switch edition {
        case .taiwanZhHant:
            return "每天用清楚、適合孩子理解的方式，看見世界正在發生的事。"
        case .japanJa:
            return "毎日、子どもにわかりやすい言葉で、世界で起きていることを見ていこう。"
        case .unitedStatesEn:
            return "See what is happening around the world each day in a way kids can follow."
        }
    }

    var todayHighlightsLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "今日精選"
        case .japanJa:
            return "きょうの特集"
        case .unitedStatesEn:
            return "Today's Picks"
        }
    }

    var readingPreferencesTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "閱讀設定"
        case .japanJa:
            return "読む設定"
        case .unitedStatesEn:
            return "Reading Setup"
        }
    }

    var currentEditionTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "目前版本"
        case .japanJa:
            return "現在の版"
        case .unitedStatesEn:
            return "Current Edition"
        }
    }

    var ageBandTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "閱讀年齡"
        case .japanJa:
            return "読む年齢"
        case .unitedStatesEn:
            return "Reading Age"
        }
    }

    var storiesSectionTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "今日世界版"
        case .japanJa:
            return "きょうの世界版"
        case .unitedStatesEn:
            return "Today's World Edition"
        }
    }

    var premiumChipTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "Premium"
        case .japanJa:
            return "Premium"
        case .unitedStatesEn:
            return "Premium"
        }
    }

    var premiumRewriteChipTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "Premium 整理稿"
        case .japanJa:
            return "Premiumまとめ稿"
        case .unitedStatesEn:
            return "Premium Brief"
        }
    }

    var premiumRewriteDetail: String {
        switch edition {
        case .taiwanZhHant:
            return "根據可信來源重整重點，幫孩子更快讀懂新聞。"
        case .japanJa:
            return "信頼できる報道をもとに要点を整理し、子どもが流れをつかみやすくしています。"
        case .unitedStatesEn:
            return "Key points are rewritten from trusted reporting so kids can follow the story more easily."
        }
    }

    var loadingStoriesLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "正在準備今日新聞"
        case .japanJa:
            return "きょうのニュースを準備中"
        case .unitedStatesEn:
            return "Preparing today's stories"
        }
    }

    var emptyStoriesTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "正在等適合孩子閱讀的真實新聞"
        case .japanJa:
            return "子ども向けに整えた本物のニュースを準備中"
        case .unitedStatesEn:
            return "Waiting for real stories that fit young readers"
        }
    }

    var emptyStoriesDetail: String {
        switch edition {
        case .taiwanZhHant:
            return "我們只顯示通過來源白名單與兒少安全規則的真實新聞。稍後再重新整理看看。"
        case .japanJa:
            return "信頼できる情報源と子ども向け安全ルールを通った本物のニュースだけを表示します。少ししてからもう一度更新してください。"
        case .unitedStatesEn:
            return "The app only shows real stories that pass trusted-source checks and kid-safe filtering. Try refreshing again in a little while."
        }
    }

    var bookmarkAccessibilityLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "收藏這則新聞"
        case .japanJa:
            return "このニュースを保存"
        case .unitedStatesEn:
            return "Save this story"
        }
    }

    var backgroundBriefTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "背景小檔案"
        case .japanJa:
            return "背景メモ"
        case .unitedStatesEn:
            return "Background Brief"
        }
    }

    var whyItMattersTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "為什麼這件事重要"
        case .japanJa:
            return "なぜ大切なのか"
        case .unitedStatesEn:
            return "Why This Matters"
        }
    }

    var thinkingPromptTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "想想看"
        case .japanJa:
            return "考えてみよう"
        case .unitedStatesEn:
            return "Think About It"
        }
    }

    var editionSettingsTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "版本與語言"
        case .japanJa:
            return "版と言語"
        case .unitedStatesEn:
            return "Edition & Language"
        }
    }

    var followSystemTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "跟隨 iOS 系統"
        case .japanJa:
            return "iOSの設定に合わせる"
        case .unitedStatesEn:
            return "Follow iOS"
        }
    }

    var manualEditionTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "手動固定版本"
        case .japanJa:
            return "手動で版を固定"
        case .unitedStatesEn:
            return "Manual Override"
        }
    }

    var chooseEditionTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "選擇閱讀版本"
        case .japanJa:
            return "読む版を選ぶ"
        case .unitedStatesEn:
            return "Choose Edition"
        }
    }

    var subscriptionTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "訂閱與解鎖"
        case .japanJa:
            return "購読とアンロック"
        case .unitedStatesEn:
            return "Subscription"
        }
    }

    var premiumEnabledTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "Premium 已啟用"
        case .japanJa:
            return "Premiumが有効です"
        case .unitedStatesEn:
            return "Premium Active"
        }
    }

    var premiumBenefitsSummary: String {
        switch edition {
        case .taiwanZhHant:
            return "目前已解鎖更多新聞數量、Premium 深度整理稿、加強版內文理解引導、完整朗讀內容、為什麼重要、背景小檔案、想想看、30 天歷史庫、收藏、離線與家長週報。"
        case .japanJa:
            return "ニュース数の拡張に加えて、Premiumの深いまとめ、理解ガイド、全文読み上げ、なぜ大切か、背景メモ、考える質問、30日分のアーカイブ、保存、オフライン、保護者向け週報が使えます。"
        case .unitedStatesEn:
            return "Premium unlocks more stories, deeper rewritten news briefs, fuller read-aloud support, richer reading guides, why-it-matters notes, background briefs, thinking prompts, a 30-day archive, saved stories, offline reading, and a weekly parent report."
        }
    }

    var unlockSummary: String {
        switch edition {
        case .taiwanZhHant:
            return "免費版保留基本朗讀與重點閱讀；升級後可解鎖 Premium 深度整理稿、更完整的新聞內文、完整朗讀、理解引導、重要性說明與延伸閱讀內容。"
        case .japanJa:
            return "無料版では基本の読み上げと要点読みに対応し、アップグレードするとPremiumの深いまとめ、全文読み上げ、理解ガイド、重要ポイント、学びの広がりが使えます。"
        case .unitedStatesEn:
            return "Free keeps basic read-aloud and key story reading. Upgrade to unlock Premium rewritten briefs, fuller read-aloud, richer story explanations, reading guides, why-it-matters notes, and deeper follow-up content."
        }
    }

    var loadingOfferingsLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "正在載入訂閱方案"
        case .japanJa:
            return "プランを読み込み中"
        case .unitedStatesEn:
            return "Loading plans"
        }
    }

    var noPlansAvailableLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "目前沒有可用方案。"
        case .japanJa:
            return "現在利用できるプランはありません。"
        case .unitedStatesEn:
            return "No plans are available right now."
        }
    }

    func subscriptionPackageTitle(for package: SubscriptionPackage) -> String {
        switch (edition, package.productIdentifier) {
        case (.taiwanZhHant, "juniorglobe.premium.monthly"):
            return "JuniorGlobe Premium 月費版"
        case (.japanJa, "juniorglobe.premium.monthly"):
            return "JuniorGlobe Premium 月額版"
        case (.unitedStatesEn, "juniorglobe.premium.monthly"):
            return "JuniorGlobe Premium Monthly"
        default:
            return package.title
        }
    }

    func subscriptionPackageSubtitle(for package: SubscriptionPackage) -> String {
        switch (edition, package.productIdentifier) {
        case (.taiwanZhHant, "juniorglobe.premium.monthly"):
            return "解鎖 6-9 歲與 9-12 歲完整內容、更多背景、脈絡與重點整理。"
        case (.japanJa, "juniorglobe.premium.monthly"):
            return "6-9歳と9-12歳向けの完全版に加え、背景・流れ・要点整理まで読めます。"
        case (.unitedStatesEn, "juniorglobe.premium.monthly"):
            return "Unlock the full 6-9 and 9-12 reading versions with more background, context, and key takeaways."
        default:
            return package.subtitle
        }
    }

    var parentGateTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "家長鎖"
        case .japanJa:
            return "保護者ロック"
        case .unitedStatesEn:
            return "Parent Lock"
        }
    }

    var parentGateLockedDetail: String {
        switch edition {
        case .taiwanZhHant:
            return "訂閱方案需要由家長先解鎖後才能查看與購買。"
        case .japanJa:
            return "プランの表示と購入は、保護者が先にロックを解除した後にだけ使えます。"
        case .unitedStatesEn:
            return "A parent needs to unlock this section before plans can be viewed or purchased."
        }
    }

    var parentGateUnlockedDetail: String {
        switch edition {
        case .taiwanZhHant:
            return "家長鎖已暫時解鎖，現在可以查看訂閱方案。"
        case .japanJa:
            return "保護者ロックが一時的に解除され、プランを表示できます。"
        case .unitedStatesEn:
            return "Parent lock is temporarily open, so plans can be viewed now."
        }
    }

    var parentGateUnlockButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "由家長解鎖"
        case .japanJa:
            return "保護者が解除する"
        case .unitedStatesEn:
            return "Parent Unlock"
        }
    }

    var parentGateUnlockedLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "家長鎖已解鎖"
        case .japanJa:
            return "保護者ロック解除中"
        case .unitedStatesEn:
            return "Parent Lock Unlocked"
        }
    }

    var parentGatePlansHiddenLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "解鎖後才會顯示訂閱方案與購買按鈕。"
        case .japanJa:
            return "解除すると、プランと購入ボタンが表示されます。"
        case .unitedStatesEn:
            return "Plans and purchase buttons appear after a parent unlocks this section."
        }
    }

    var parentGateAuthenticationReason: String {
        switch edition {
        case .taiwanZhHant:
            return "請由家長解鎖 JuniorGlobe 的訂閱與購買區。"
        case .japanJa:
            return "JuniorGlobeの購読と購入エリアを保護者が解除してください。"
        case .unitedStatesEn:
            return "A parent needs to unlock JuniorGlobe's subscription area."
        }
    }

    var parentGateUnlockFailedLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "目前無法解鎖訂閱區，請再試一次。"
        case .japanJa:
            return "購読エリアを解除できませんでした。もう一度試してください。"
        case .unitedStatesEn:
            return "The subscription area could not be unlocked. Please try again."
        }
    }

    var parentGateFallbackTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "家長解鎖"
        case .japanJa:
            return "保護者による解除"
        case .unitedStatesEn:
            return "Parent Unlock"
        }
    }

    var parentGateFallbackDetail: String {
        switch edition {
        case .taiwanZhHant:
            return "請由家長回答下面的簡單加減題，答對後才會顯示訂閱方案。"
        case .japanJa:
            return "保護者が下のかんたんな足し算か引き算に答えると、プランを表示できます。"
        case .unitedStatesEn:
            return "A parent needs to answer the simple math problem below before subscription plans can be shown."
        }
    }

    func parentGateFallbackPrompt(_ challenge: ParentGateChallenge) -> String {
        "\(challenge.firstNumber) \(challenge.operation.symbol) \(challenge.secondNumber) = ?"
    }

    var parentGateFallbackPlaceholder: String {
        switch edition {
        case .taiwanZhHant:
            return "請輸入答案"
        case .japanJa:
            return "答えを入力"
        case .unitedStatesEn:
            return "Enter the answer"
        }
    }

    var parentGateFallbackErrorLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "答案不正確，請由家長再試一次。"
        case .japanJa:
            return "答えがちがいます。保護者がもう一度試してください。"
        case .unitedStatesEn:
            return "That answer was not correct. Please let a parent try again."
        }
    }

    var parentGateConfirmButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "確認並解鎖"
        case .japanJa:
            return "確認して解除"
        case .unitedStatesEn:
            return "Confirm and Unlock"
        }
    }

    var parentGateCancelButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "取消"
        case .japanJa:
            return "キャンセル"
        case .unitedStatesEn:
            return "Cancel"
        }
    }

    var playNarrationButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "播放朗讀"
        case .japanJa:
            return "読み上げる"
        case .unitedStatesEn:
            return "Play Audio"
        }
    }

    var stopNarrationButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "停止朗讀"
        case .japanJa:
            return "読み上げを止める"
        case .unitedStatesEn:
            return "Stop Audio"
        }
    }

    var cancelNarrationPreparationButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "取消語音生成"
        case .japanJa:
            return "音声生成を止める"
        case .unitedStatesEn:
            return "Cancel Audio"
        }
    }

    var retryNarrationButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "重新生成語音"
        case .japanJa:
            return "音声を作り直す"
        case .unitedStatesEn:
            return "Retry Audio"
        }
    }

    func narrationButtonTitle(for status: StoryNarrationStatus?) -> String {
        guard let status else {
            return playNarrationButtonTitle
        }

        switch status.stage {
        case .requestingScript, .generatingAudio, .preparingPlayback:
            return cancelNarrationPreparationButtonTitle
        case .playing:
            return stopNarrationButtonTitle
        case .failed:
            return retryNarrationButtonTitle
        }
    }

    func narrationProgressLabel(for stage: StoryNarrationStage) -> String {
        switch stage {
        case .requestingScript:
            switch edition {
            case .taiwanZhHant:
                return "正在整理逐字稿"
            case .japanJa:
                return "読み上げ原稿を整えています"
            case .unitedStatesEn:
                return "Preparing the narration script"
            }
        case .generatingAudio:
            switch edition {
            case .taiwanZhHant:
                return "正在生成 AI 聲音"
            case .japanJa:
                return "AI音声を生成しています"
            case .unitedStatesEn:
                return "Generating the AI voice"
            }
        case .preparingPlayback:
            switch edition {
            case .taiwanZhHant:
                return "正在準備播放"
            case .japanJa:
                return "再生の準備をしています"
            case .unitedStatesEn:
                return "Preparing playback"
            }
        case .playing:
            switch edition {
            case .taiwanZhHant:
                return "正在播放 AI 朗讀"
            case .japanJa:
                return "AI読み上げを再生中"
            case .unitedStatesEn:
                return "Playing AI narration"
            }
        case let .failed(reason):
            return narrationFailureMessage(for: reason)
        }
    }

    func narrationProgressDetail(for stage: StoryNarrationStage) -> String {
        switch stage {
        case .requestingScript:
            switch edition {
            case .taiwanZhHant:
                return "先把新聞整理成適合孩子聽懂的逐字稿。"
            case .japanJa:
                return "まず、子どもが聞き取りやすい読み上げ原稿に整えています。"
            case .unitedStatesEn:
                return "First, the story is being shaped into a kid-friendly narration script."
            }
        case .generatingAudio:
            switch edition {
            case .taiwanZhHant:
                return "正在把逐字稿轉成更自然的 AI 聲音。"
            case .japanJa:
                return "原稿を、より自然なAI音声に変えています。"
            case .unitedStatesEn:
                return "The script is being turned into a more natural AI voice."
            }
        case .preparingPlayback:
            switch edition {
            case .taiwanZhHant:
                return "語音快完成了，正在下載並對齊句子高亮。"
            case .japanJa:
                return "音声はほぼ完成です。ダウンロードして文ごとのハイライトに合わせています。"
            case .unitedStatesEn:
                return "The audio is almost ready and is being synced with sentence highlighting."
            }
        case .playing:
            switch edition {
            case .taiwanZhHant:
                return "現在會跟著句子一起高亮播放。"
            case .japanJa:
                return "文ごとのハイライトに合わせて再生します。"
            case .unitedStatesEn:
                return "Playback now stays in sync with sentence highlighting."
            }
        case let .failed(reason):
            return narrationFailureRecoveryHint(for: reason)
        }
    }

    func narrationStageShortLabel(for stage: StoryNarrationStage) -> String {
        switch stage {
        case .requestingScript:
            switch edition {
            case .taiwanZhHant:
                return "逐字稿"
            case .japanJa:
                return "原稿"
            case .unitedStatesEn:
                return "Script"
            }
        case .generatingAudio:
            switch edition {
            case .taiwanZhHant:
                return "語音"
            case .japanJa:
                return "音声"
            case .unitedStatesEn:
                return "Voice"
            }
        case .preparingPlayback:
            switch edition {
            case .taiwanZhHant:
                return "播放"
            case .japanJa:
                return "再生"
            case .unitedStatesEn:
                return "Play"
            }
        case .playing, .failed:
            switch edition {
            case .taiwanZhHant:
                return "朗讀"
            case .japanJa:
                return "読み上げ"
            case .unitedStatesEn:
                return "Audio"
            }
        }
    }

    func narrationFailureMessage(for reason: StoryNarrationFailureReason) -> String {
        switch edition {
        case .taiwanZhHant:
            switch reason {
            case .serviceUnavailable:
                return "AI 語音服務暫時不可用。"
            case .timedOut:
                return "AI 語音生成逾時，請稍後再試。"
            case .invalidResponse, .generationFailed:
                return "AI 語音這次沒有順利完成，請再試一次。"
            }
        case .japanJa:
            switch reason {
            case .serviceUnavailable:
                return "AI音声サービスは現在利用できません。"
            case .timedOut:
                return "AI音声の生成に時間がかかりすぎました。あとでもう一度お試しください。"
            case .invalidResponse, .generationFailed:
                return "AI音声をうまく作れませんでした。もう一度お試しください。"
            }
        case .unitedStatesEn:
            switch reason {
            case .serviceUnavailable:
                return "The AI voice service is not available right now."
            case .timedOut:
                return "The AI voice took too long to generate. Please try again."
            case .invalidResponse, .generationFailed:
                return "The AI voice did not finish successfully. Please try again."
            }
        }
    }

    func narrationFailureRecoveryHint(for reason: StoryNarrationFailureReason) -> String {
        switch edition {
        case .taiwanZhHant:
            switch reason {
            case .serviceUnavailable:
                return "可以稍後再試，或等網路穩定後重新生成。"
            case .timedOut:
                return "點一下重新生成語音，通常下一次會更快完成。"
            case .invalidResponse, .generationFailed:
                return "點一下重新生成語音，再做一次新的 AI 配音。"
            }
        case .japanJa:
            switch reason {
            case .serviceUnavailable:
                return "少し時間をおいて、通信が安定してからもう一度お試しください。"
            case .timedOut:
                return "もう一度タップして音声を作り直すと、次は早く終わることがあります。"
            case .invalidResponse, .generationFailed:
                return "もう一度タップすると、新しくAI音声を作り直します。"
            }
        case .unitedStatesEn:
            switch reason {
            case .serviceUnavailable:
                return "Try again in a moment, or wait for a steadier connection."
            case .timedOut:
                return "Tap to retry and the next voice generation often finishes faster."
            case .invalidResponse, .generationFailed:
                return "Tap to retry and the app will generate a fresh AI narration."
            }
        }
    }

    func narrationAccessibilityLabel(status: StoryNarrationStatus?) -> String {
        narrationButtonTitle(for: status)
    }

    var upgradePremiumButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "升級 Premium"
        case .japanJa:
            return "Premiumにする"
        case .unitedStatesEn:
            return "Upgrade to Premium"
        }
    }

    var premiumLibraryTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "Premium 圖書館"
        case .japanJa:
            return "Premiumライブラリ"
        case .unitedStatesEn:
            return "Premium Library"
        }
    }

    var archiveTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "30 天歷史庫"
        case .japanJa:
            return "30日アーカイブ"
        case .unitedStatesEn:
            return "30-Day Archive"
        }
    }

    var favoritesTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "收藏"
        case .japanJa:
            return "保存"
        case .unitedStatesEn:
            return "Saved Stories"
        }
    }

    var weeklyReportTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "家長週報"
        case .japanJa:
            return "保護者向け週報"
        case .unitedStatesEn:
            return "Parent Weekly Report"
        }
    }

    var weeklyReportGuidanceTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "陪讀建議"
        case .japanJa:
            return "いっしょに読むヒント"
        case .unitedStatesEn:
            return "Conversation Prompt"
        }
    }

    var weeklyReportEmptyLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "連續看幾天新聞後，這裡會整理孩子最近接觸到的世界區域、主題與可信來源。"
        case .japanJa:
            return "数日続けて読むと、ここに最近ふれた地域、テーマ、信頼できる情報源がまとまります。"
        case .unitedStatesEn:
            return "After a few days of reading, this report will summarize the regions, topics, and trusted sources your child has explored."
        }
    }

    var weeklyReportDistributionTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "閱讀領域分佈"
        case .japanJa:
            return "読む分野の分布"
        case .unitedStatesEn:
            return "Reading Domain Split"
        }
    }

    var weeklyReportDistributionDetail: String {
        switch edition {
        case .taiwanZhHant:
            return "看孩子最近一週最常接觸哪些新聞領域。"
        case .japanJa:
            return "この1週間で、どのニュース分野に多くふれたかを見られます。"
        case .unitedStatesEn:
            return "See which story domains your child explored most this week."
        }
    }

    var weeklyReportAnalysisTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "閱讀分析"
        case .japanJa:
            return "読み方の分析"
        case .unitedStatesEn:
            return "Reading Analysis"
        }
    }

    var accountActionsTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "帳號操作"
        case .japanJa:
            return "アカウント操作"
        case .unitedStatesEn:
            return "Account Actions"
        }
    }

    var refreshingStoriesLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "正在更新今日新聞"
        case .japanJa:
            return "きょうのニュースを更新中"
        case .unitedStatesEn:
            return "Updating today's stories"
        }
    }

    var refreshNewsButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "重新整理新聞"
        case .japanJa:
            return "ニュースを更新"
        case .unitedStatesEn:
            return "Refresh News"
        }
    }

    var restorePurchasesButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "還原購買"
        case .japanJa:
            return "購入を復元"
        case .unitedStatesEn:
            return "Restore Purchases"
        }
    }

    var archivePageEmptyLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "最近 30 天的新聞會在你閱讀後自動存到這裡，之後就算沒網路也能回看。"
        case .japanJa:
            return "ここには最近30日分のニュースが自動で保存され、オフラインでも読み返せます。"
        case .unitedStatesEn:
            return "Stories from the last 30 days are saved here automatically so your child can revisit them offline."
        }
    }

    var archiveDayOfflineDescription: String {
        switch edition {
        case .taiwanZhHant:
            return "這份新聞日包已存到裝置，可離線閱讀。"
        case .japanJa:
            return "この日別パックは端末に保存されていて、オフラインで読めます。"
        case .unitedStatesEn:
            return "This daily news pack is saved on the device and available offline."
        }
    }

    var favoritesPageEmptyLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "收藏會把你想回頭比較或討論的新聞留下來，之後可離線閱讀。"
        case .japanJa:
            return "保存すると、あとで比べたり話したりしたいニュースをオフラインでも読み返せます。"
        case .unitedStatesEn:
            return "Saved stories let your child revisit and compare stories later, even offline."
        }
    }

    var removeFavoriteAccessibilityLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "取消收藏"
        case .japanJa:
            return "保存を解除"
        case .unitedStatesEn:
            return "Remove saved story"
        }
    }

    var offlineReadyLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "離線可讀"
        case .japanJa:
            return "オフライン対応"
        case .unitedStatesEn:
            return "Offline Ready"
        }
    }

    var archiveStatusEmptyLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "尚未建立"
        case .japanJa:
            return "まだありません"
        case .unitedStatesEn:
            return "Not Yet"
        }
    }

    var archiveStatusReadyLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "已建立"
        case .japanJa:
            return "保存済み"
        case .unitedStatesEn:
            return "Saved"
        }
    }

    func editionAgeStatus(currentEdition: AppEdition, ageBand: AgeBand) -> String {
        "\(currentEdition.shortLabel(in: edition)) ・ \(ageBand.label(for: edition))"
    }

    func storyProgressLabel(visible: Int, total: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(visible)/\(total) 則"
        case .japanJa:
            return "\(visible)/\(total)本"
        case .unitedStatesEn:
            return "\(visible)/\(total) stories"
        }
    }

    func minutesLabel(_ minutes: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(minutes) 分鐘"
        case .japanJa:
            return "\(minutes)分"
        case .unitedStatesEn:
            return "\(minutes) min"
        }
    }

    func storyCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 則"
        case .japanJa:
            return "\(count)本"
        case .unitedStatesEn:
            return "\(count) stories"
        }
    }

    func regionCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 區域"
        case .japanJa:
            return "\(count)地域"
        case .unitedStatesEn:
            return "\(count) regions"
        }
    }

    func sourceCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 來源"
        case .japanJa:
            return "\(count)媒体"
        case .unitedStatesEn:
            return "\(count) sources"
        }
    }

    func categoryCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 主題"
        case .japanJa:
            return "\(count)テーマ"
        case .unitedStatesEn:
            return "\(count) topics"
        }
    }

    func readingDayCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 天閱讀"
        case .japanJa:
            return "\(count)日読んだ"
        case .unitedStatesEn:
            return "\(count) reading days"
        }
    }

    func favoriteCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 則收藏"
        case .japanJa:
            return "\(count)本保存"
        case .unitedStatesEn:
            return "\(count) saved"
        }
    }

    func editionCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 個版本"
        case .japanJa:
            return "\(count)つの版"
        case .unitedStatesEn:
            return "\(count) editions"
        }
    }

    func ageBandCountLabel(_ count: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(count) 個年齡層"
        case .japanJa:
            return "\(count)つの年齢帯"
        case .unitedStatesEn:
            return "\(count) age bands"
        }
    }

    func shareLabel(_ share: Double) -> String {
        let percentage = Int((share * 100).rounded())

        switch edition {
        case .taiwanZhHant, .japanJa:
            return "\(percentage)％"
        case .unitedStatesEn:
            return "\(percentage)%"
        }
    }

    func categoryDistributionDetailLabel(storyCount: Int, share: Double) -> String {
        switch edition {
        case .taiwanZhHant:
            return "\(storyCount) 則 ・ \(shareLabel(share))"
        case .japanJa:
            return "\(storyCount)本 ・ \(shareLabel(share))"
        case .unitedStatesEn:
            return "\(storyCount) stories · \(shareLabel(share))"
        }
    }

    func freeSummary(visibleStories: Int, totalStories: Int) -> String {
        switch edition {
        case .taiwanZhHant:
            return "免費版可先看 \(visibleStories) 則重點並保留基本朗讀，Premium 會再解鎖完整 \(totalStories) 則世界版與深度整理稿。"
        case .japanJa:
            return "無料版では \(visibleStories)本の要点と基本の読み上げが使え、Premiumで全 \(totalStories)本の世界版と深いまとめを開けます。"
        case .unitedStatesEn:
            return "Free readers can start with \(visibleStories) key stories and basic read-aloud. Premium unlocks the full \(totalStories)-story world edition and deeper rewritten briefs."
        }
    }

    func followSystemDetail(systemEdition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return "首次使用時會跟著 iOS 語系使用 \(systemEdition.displayName(in: edition))；手動更改後會記住你選擇的版本。"
        case .japanJa:
            return "最初はiOSの言語設定に合わせて \(systemEdition.displayName(in: edition)) を使い、手動で変えるとその版を記憶します。"
        case .unitedStatesEn:
            return "By default the app follows iOS and uses \(systemEdition.displayName(in: edition)). If you switch editions, the app will remember your choice."
        }
    }

    func manualEditionSavedDetail(currentEdition: AppEdition) -> String {
        switch edition {
        case .taiwanZhHant:
            return "目前已固定使用 \(currentEdition.displayName(in: edition))，之後會維持這個版本。"
        case .japanJa:
            return "現在は \(currentEdition.displayName(in: edition)) に固定されていて、この版を使い続けます。"
        case .unitedStatesEn:
            return "The app is currently locked to \(currentEdition.displayName(in: edition)) and will keep using this edition."
        }
    }

    var useSystemDefaultButtonTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "改回跟隨 iOS 系統"
        case .japanJa:
            return "iOSの設定に戻す"
        case .unitedStatesEn:
            return "Use iOS Default Again"
        }
    }

    func archiveDetail(entryCount: Int) -> String {
        guard entryCount > 0 else {
            switch edition {
            case .taiwanZhHant:
                return "最近 30 天的新聞會自動存到裝置，可離線回看。"
            case .japanJa:
                return "最近30日分のニュースは端末に自動保存され、オフラインで読み返せます。"
            case .unitedStatesEn:
                return "Stories from the past 30 days are saved automatically for offline reading."
            }
        }

        switch edition {
        case .taiwanZhHant:
            return "目前有 \(entryCount) 份新聞日包可離線開啟。"
        case .japanJa:
            return "現在 \(entryCount) 件の日別ニュースパックをオフラインで開けます。"
        case .unitedStatesEn:
            return "\(entryCount) daily packs are ready to open offline."
        }
    }

    func favoritesDetail(recordCount: Int) -> String {
        guard recordCount > 0 else {
            switch edition {
            case .taiwanZhHant:
                return "把想回頭比較的新聞先存起來。"
            case .japanJa:
                return "あとで比べたいニュースを保存しておこう。"
            case .unitedStatesEn:
                return "Save stories your child wants to revisit and compare."
            }
        }

        switch edition {
        case .taiwanZhHant:
            return "目前已收藏 \(recordCount) 則新聞。"
        case .japanJa:
            return "現在 \(recordCount) 本のニュースを保存しています。"
        case .unitedStatesEn:
            return "\(recordCount) stories are currently saved."
        }
    }

    func archiveDayHeader(edition: AppEdition, ageBand: AgeBand, storyCount: Int) -> String {
        switch self.edition {
        case .taiwanZhHant:
            return "\(edition.displayName(in: self.edition)) ・ \(ageBand.label(for: self.edition)) ・ \(storyCount) 則"
        case .japanJa:
            return "\(edition.displayName(in: self.edition)) ・ \(ageBand.label(for: self.edition)) ・ \(storyCount)本"
        case .unitedStatesEn:
            return "\(edition.displayName(in: self.edition)) · \(ageBand.label(for: self.edition)) · \(storyCount) stories"
        }
    }

    func savedAtLabel(_ date: Date) -> String {
        switch edition {
        case .taiwanZhHant:
            return "收藏於 \(timestampString(date))"
        case .japanJa:
            return "\(timestampString(date)) に保存"
        case .unitedStatesEn:
            return "Saved \(timestampString(date))"
        }
    }

    func lastUpdatedString(_ date: Date) -> String {
        switch edition {
        case .taiwanZhHant:
            return "更新時間 \(timestampString(date))"
        case .japanJa:
            return "更新 \(timestampString(date))"
        case .unitedStatesEn:
            return "Updated \(timestampString(date))"
        }
    }

    func dayLabel(for dayKey: String) -> String {
        guard let date = dayKeyDate(dayKey) else {
            return dayKey
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = edition.locale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate(edition == .unitedStatesEn ? "MMM d" : "M d")
        return formatter.string(from: date)
    }

    func parentReportSummary(_ report: ParentWeeklyReport) -> String {
        let topRegions = report.topRegions.map { $0.label(for: edition) }.joined(separator: edition == .unitedStatesEn ? ", " : "、")
        let topCategories = report.topCategories.map { $0.label(for: edition) }.joined(separator: edition == .unitedStatesEn ? ", " : "、")

        switch edition {
        case .taiwanZhHant:
            return "這 7 天孩子共閱讀 \(report.storyCount) 則新聞、約 \(report.estimatedReadingMinutes) 分鐘，涵蓋 \(report.regionCount) 個世界區域、\(report.categoryCount) 個主題與 \(report.sourceCount) 個可信來源。最常接觸的是\(topRegions)與\(topCategories)題材。"
        case .japanJa:
            return "この7日間で、子どもは \(report.storyCount) 本のニュースを読み、約 \(report.estimatedReadingMinutes) 分ふれました。\(report.regionCount) 地域、\(report.categoryCount) テーマ、\(report.sourceCount) の信頼できる情報源に広がっています。よく読んだのは \(topRegions) と \(topCategories) の話題です。"
        case .unitedStatesEn:
            return "Over the last 7 days, your child explored \(report.storyCount) stories in about \(report.estimatedReadingMinutes) minutes across \(report.regionCount) world regions, \(report.categoryCount) domains, and \(report.sourceCount) trusted sources. The most common themes were \(topRegions) and \(topCategories)."
        }
    }

    func weeklyReportFocusSummary(_ report: ParentWeeklyReport) -> String {
        let dominantLabel = report.dominantCategory?.label(for: edition) ?? report.topCategories.first?.label(for: edition) ?? ""
        let dominantShare = report.categoryDistribution.first?.share ?? 0

        switch edition {
        case .taiwanZhHant:
            if report.categoryCount >= 4 {
                return "本週閱讀廣度不錯，已接觸 \(report.categoryCount) 種領域；其中 \(dominantLabel) 佔比最高，約 \(shareLabel(dominantShare))。"
            }
            return "本週閱讀較集中在 \(dominantLabel)，約佔 \(shareLabel(dominantShare))。下週可以多補一點不同領域，讓世界觀更平衡。"
        case .japanJa:
            if report.categoryCount >= 4 {
                return "今週は \(report.categoryCount) つの分野にふれていて、広がりがあります。中でも \(dominantLabel) がもっとも多く、約 \(shareLabel(dominantShare)) です。"
            }
            return "今週は \(dominantLabel) に読みが集まり、約 \(shareLabel(dominantShare)) を占めました。来週は別の分野も少し足すと、視野がさらに広がります。"
        case .unitedStatesEn:
            if report.categoryCount >= 4 {
                return "This week shows good breadth across \(report.categoryCount) domains. \(dominantLabel) led the mix at about \(shareLabel(dominantShare))."
            }
            return "This week was more concentrated in \(dominantLabel), which made up about \(shareLabel(dominantShare)) of reading. Adding another domain next week would broaden the mix."
        }
    }

    func weeklyReportTrackingSummary(_ report: ParentWeeklyReport) -> String {
        let dominantEdition = report.dominantEdition?.displayName(in: edition) ?? edition.displayName(in: edition)
        let dominantAgeBand = report.dominantAgeBand?.label(for: edition) ?? ""

        switch edition {
        case .taiwanZhHant:
            return "這週共閱讀 \(report.daysCovered) 天、收藏 \(report.favoriteCount) 則，主要集中在 \(dominantEdition) 與 \(dominantAgeBand) 閱讀層級。"
        case .japanJa:
            return "今週は \(report.daysCovered)日読み、\(report.favoriteCount)本を保存しました。主に \(dominantEdition) と \(dominantAgeBand) の読み方が中心です。"
        case .unitedStatesEn:
            return "Your child read on \(report.daysCovered) days and saved \(report.favoriteCount) stories this week, mostly in \(dominantEdition) at \(dominantAgeBand)."
        }
    }

    func weeklyReportNextStretchSummary(_ report: ParentWeeklyReport) -> String {
        guard let suggestedCategory = report.suggestedNextCategory else {
            switch edition {
            case .taiwanZhHant:
                return "這週各領域都有接觸，可以延續孩子最有興趣的主題再往下深挖。"
            case .japanJa:
                return "今週はどの分野にもふれられているので、子どもがいちばん気になったテーマを深めてみましょう。"
            case .unitedStatesEn:
                return "This week already covered every domain, so you can deepen whichever topic your child found most interesting."
            }
        }

        switch edition {
        case .taiwanZhHant:
            return "下週可以特別補一點\(suggestedCategory.label(for: edition))新聞，讓孩子看到更多不同的世界解法。"
        case .japanJa:
            return "来週は \(suggestedCategory.label(for: edition)) のニュースを少し足すと、世界の見方がもっと広がります。"
        case .unitedStatesEn:
            return "Next week, try adding a little more \(suggestedCategory.label(for: edition)) coverage to widen the overall mix."
        }
    }

    func parentConversationPrompt(_ report: ParentWeeklyReport) -> String {
        if let firstCategory = report.topCategories.first {
            switch edition {
            case .taiwanZhHant:
                return "本週可以挑一則\(firstCategory.label(for: edition))新聞，和孩子一起比較不同地方為什麼會做出不同選擇。"
            case .japanJa:
                return "今週は \(firstCategory.label(for: edition)) のニュースを1本選んで、地域によって選び方がどう違うかを子どもと話してみましょう。"
            case .unitedStatesEn:
                return "This week, pick one \(firstCategory.label(for: edition)) story and compare why different places might make different choices."
            }
        }

        switch edition {
        case .taiwanZhHant:
            return "本週可以挑一則孩子最有印象的新聞，問他這件事和哪個地方、哪種生活最有關係。"
        case .japanJa:
            return "今週は子どもがいちばん印象に残ったニュースを選び、どの地域や暮らし方と強くつながっているかを聞いてみましょう。"
        case .unitedStatesEn:
            return "This week, ask your child which story stood out most and what place or way of life it connected to."
        }
    }

    func parentReportDateRange(_ report: ParentWeeklyReport) -> String {
        guard
            let startDayKey = report.startDayKey,
            let endDayKey = report.endDayKey,
            let startDate = dayKeyDate(startDayKey),
            let endDate = dayKeyDate(endDayKey)
        else {
            switch edition {
            case .taiwanZhHant:
                return "最近 7 天"
            case .japanJa:
                return "最近7日"
            case .unitedStatesEn:
                return "Last 7 Days"
            }
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = edition.locale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate(edition == .unitedStatesEn ? "MMM d" : "M d")
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var legalPrivacyTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "法律與隱私"
        case .japanJa:
            return "法的情報とプライバシー"
        case .unitedStatesEn:
            return "Legal & Privacy"
        }
    }

    var legalPrivacySummary: String {
        switch edition {
        case .taiwanZhHant:
            return "這裡整理 JuniorGlobe 目前版本的兒少隱私說明、Apple 標準 EULA，以及 app 實際的資料處理方式。"
        case .japanJa:
            return "JuniorGlobe の現行版について、子どものプライバシーに関する説明、Apple 標準 EULA、現在のデータ取り扱い内容をまとめています。"
        case .unitedStatesEn:
            return "This section explains JuniorGlobe's current child-privacy notice, Apple Standard EULA reference, and how the current app version handles data."
        }
    }

    var legalPrivacyLastUpdatedLabel: String {
        switch edition {
        case .taiwanZhHant:
            return "最後更新：2026 年 4 月 27 日"
        case .japanJa:
            return "最終更新日：2026年4月27日"
        case .unitedStatesEn:
            return "Last updated: April 27, 2026"
        }
    }

    var legalPrivacySupportTitle: String {
        switch edition {
        case .taiwanZhHant:
            return "支援與隱私聯絡"
        case .japanJa:
            return "サポートとプライバシー連絡先"
        case .unitedStatesEn:
            return "Support & Privacy Contact"
        }
    }

    var legalPrivacySupportIdentity: String {
        switch edition {
        case .taiwanZhHant:
            return "開發者：Hsueh Yi An"
        case .japanJa:
            return "開発者：Hsueh Yi An"
        case .unitedStatesEn:
            return "Developer: Hsueh Yi An"
        }
    }

    var legalPrivacySupportSummary: String {
        switch edition {
        case .taiwanZhHant:
            return "若家長對兒少隱私、訂閱、資料處理或 Apple 內購條款有問題，請使用下方信箱聯絡。"
        case .japanJa:
            return "子どものプライバシー、購読、データの取り扱い、App Store の課金条件について保護者の方が質問される場合は、下記のメールアドレスへご連絡ください。"
        case .unitedStatesEn:
            return "Parents can use the email below for questions about child privacy, subscriptions, data handling, or App Store purchase terms."
        }
    }

    var legalDocuments: [LegalDocumentContent] {
        LegalContentCatalog.documents(for: edition)
    }

    private func timestampString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = edition.locale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate(edition == .unitedStatesEn ? "MMM d, HH:mm" : "M d HH:mm")
        return formatter.string(from: date)
    }

    private func dayKeyDate(_ dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }
}

private enum LegalContentCatalog {
    static let appleStandardEULAURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let applePrivacyDetailsURL = "https://developer.apple.com/app-store/app-privacy-details/"
    static let coppaURL = "https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa"

    static func documents(for edition: AppEdition) -> [LegalDocumentContent] {
        switch edition {
        case .taiwanZhHant:
            return traditionalChineseDocuments
        case .japanJa:
            return japaneseDocuments
        case .unitedStatesEn:
            return englishDocuments
        }
    }

    private static let traditionalChineseDocuments: [LegalDocumentContent] = [
        LegalDocumentContent(
            title: "COPPA 與兒少隱私說明",
            introduction: "JuniorGlobe 是為孩子閱讀世界新聞而設計的 app。我們把付款、還原購買與家長週報等家長功能放在家長鎖後方，並盡量減少兒童個人資料的收集。",
            sections: [
                LegalDocumentSectionContent(
                    title: "我們如何降低兒少資料收集",
                    paragraphs: [
                        "目前版本不要求孩子建立帳號、設定公開個人檔案、上傳照片、張貼公開內容或加入聊天室。",
                        "核心閱讀功能目前不需要聯絡人、相機、相簿、麥克風或精確位置權限。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "哪些情況可能會有資料傳輸",
                    paragraphs: [
                        "當 app 讀取新聞來源、Apple 付款流程、RevenueCat 訂閱狀態或 app 設定的後端服務時，相關服務可能依一般網路運作處理 IP 位址與標準請求資訊。",
                        "當使用 AI 朗讀時，所選新聞文字、語言、閱讀年齡與語音設定會送到 app 設定的語音服務生成音檔。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "家長權利與聯絡方式",
                    paragraphs: [
                        "家長如對兒少隱私、付款或資料處理有疑問，可以透過本頁底部的支援信箱聯絡開發者。",
                        "若家長不希望新聞文字送到遠端語音服務，請不要使用 AI 朗讀功能。"
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "FTC COPPA 官方說明", urlString: coppaURL),
                LegalDocumentLink(title: "Apple App Privacy Details 官方頁面", urlString: applePrivacyDetailsURL)
            ]
        ),
        LegalDocumentContent(
            title: "Apple 標準 EULA",
            introduction: "透過 App Store 下載與使用 JuniorGlobe 時，亦受 Apple 的《Licensed Application End User License Agreement》約束。",
            sections: [
                LegalDocumentSectionContent(
                    title: "適用方式",
                    paragraphs: [
                        "除非 app 另行提供自訂終端使用者授權合約，JuniorGlobe 目前採用 Apple App Store 的標準授權條款。",
                        "授權範圍、外部服務、免責聲明、責任限制與準據法等正式條款，請以 Apple 官方文件為準。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "與本 app 功能的關係",
                    paragraphs: [
                        "JuniorGlobe 會連線到新聞來源、訂閱服務與遠端語音服務；這些外部服務的可用性可能影響 app 內容或朗讀功能。",
                        "App Store 的購買、退款與裝置使用規則，仍以 Apple 的條款與商店流程為準。"
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "Apple Standard EULA 官方連結", urlString: appleStandardEULAURL)
            ]
        ),
        LegalDocumentContent(
            title: "隱私權政策",
            introduction: "這份政策只描述 JuniorGlobe 目前版本實際存在的資料處理方式，不涵蓋尚未上線的功能。",
            sections: [
                LegalDocumentSectionContent(
                    title: "儲存在裝置上的資料",
                    paragraphs: [
                        "語言/版本偏好與閱讀年齡設定會儲存在裝置的 UserDefaults。",
                        "Premium 使用者的收藏、30 天 archive 與家長週報資料會儲存在裝置本機；家長週報是由本機資料整理而成。",
                        "AI 朗讀產生的音檔會快取在裝置上，用來加快再次播放，舊快取會自動清理。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "透過網路請求的資料",
                    paragraphs: [
                        "app 會向可信新聞來源抓取 RSS 或新聞資料。",
                        "若你使用訂閱功能，Apple 與 RevenueCat 會處理購買、還原購買與訂閱權限狀態。",
                        "若啟用 Premium 整理稿服務，app 可能向設定的 rewrite 服務請求對應語言的整理版新聞 feed。",
                        "若使用 AI 朗讀，app 會把所選新聞文字、語言、閱讀年齡與語音設定送到設定的語音服務。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "我們目前不做的事",
                    paragraphs: [
                        "目前版本不提供兒童社群貼文、公開聊天、個人化廣告或 app 內帳號註冊。",
                        "目前不會為核心功能主動要求聯絡人、相機、相簿、麥克風或精確位置權限。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "保存與控制",
                    paragraphs: [
                        "刪除 app 會移除裝置上的本機資料。",
                        "若 Premium 權限取消，與 Premium library 相關的本機 archive 與收藏資料可能會被清除。"
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "Apple App Privacy Details 官方頁面", urlString: applePrivacyDetailsURL),
                LegalDocumentLink(title: "Apple Standard EULA 官方連結", urlString: appleStandardEULAURL)
            ]
        )
    ]

    private static let japaneseDocuments: [LegalDocumentContent] = [
        LegalDocumentContent(
            title: "COPPA と子どものプライバシー",
            introduction: "JuniorGlobe は子どもが世界のニュースを読みやすくするための app です。課金、購入の復元、保護者向け週次レポートなどの保護者機能はペアレンタルゲートの後ろに配置し、子どもの個人情報の収集をできるだけ抑える方針です。",
            sections: [
                LegalDocumentSectionContent(
                    title: "収集を抑えるための設計",
                    paragraphs: [
                        "現行版では、子どもにアカウント作成、公開プロフィール設定、写真投稿、公開投稿、チャット参加を求めていません。",
                        "基本の読書機能のために、連絡先、カメラ、写真、マイク、正確な位置情報の権限は要求していません。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "通信が発生する場面",
                    paragraphs: [
                        "app がニュースソース、Apple の課金処理、RevenueCat の購読状態、または app に設定されたバックエンドへ接続する際、通常のネットワーク動作として IP アドレスや標準的なリクエスト情報が各サービスで処理される場合があります。",
                        "AI 音声読み上げを使うと、選択したニュース本文、言語、読書年齢、音声設定が、音声生成のために app に設定された音声サービスへ送信されます。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "保護者の権利と連絡先",
                    paragraphs: [
                        "子どものプライバシー、課金、データ取り扱いについて保護者が質問する場合は、このページ下部のサポートメールから開発者へ連絡できます。",
                        "ニュース本文が遠隔音声サービスへ送信されることを望まない場合は、AI 読み上げ機能を使用しないでください。"
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "FTC COPPA 公式ページ", urlString: coppaURL),
                LegalDocumentLink(title: "Apple App Privacy Details 公式ページ", urlString: applePrivacyDetailsURL)
            ]
        ),
        LegalDocumentContent(
            title: "Apple 標準 EULA",
            introduction: "App Store から JuniorGlobe をダウンロードして利用する場合、Apple の \"Licensed Application End User License Agreement\" も適用されます。",
            sections: [
                LegalDocumentSectionContent(
                    title: "適用範囲",
                    paragraphs: [
                        "app 独自の利用許諾契約が別途提示されない限り、JuniorGlobe は Apple App Store の標準利用許諾条件に従います。",
                        "利用許諾の範囲、外部サービス、免責、責任制限、準拠法などの正式な条項は Apple の公式文書を基準としてください。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "本 app との関係",
                    paragraphs: [
                        "JuniorGlobe はニュースソース、購読サービス、遠隔音声サービスへ接続するため、これら外部サービスの可用性が app の内容や読み上げ機能に影響する場合があります。",
                        "App Store の購入、返金、デバイス利用ルールは Apple の条件とストア運用が優先されます。"
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "Apple Standard EULA 公式リンク", urlString: appleStandardEULAURL)
            ]
        ),
        LegalDocumentContent(
            title: "プライバシーポリシー",
            introduction: "このポリシーは JuniorGlobe の現行版で実際に存在するデータ取り扱いのみを説明します。未公開機能は含みません。",
            sections: [
                LegalDocumentSectionContent(
                    title: "端末内に保存される情報",
                    paragraphs: [
                        "言語/版の設定と読書年齢設定は、端末の UserDefaults に保存されます。",
                        "Premium 利用時の保存記事、30 日アーカイブ、保護者向け週次レポート用データは端末内に保存され、週次レポートはそのローカルデータから作成されます。",
                        "AI 読み上げで生成された音声ファイルは再生待ち時間を短くするため端末にキャッシュされ、古いキャッシュは自動的に整理されます。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "ネットワーク経由で扱う情報",
                    paragraphs: [
                        "app は信頼できるニュースソースから RSS やニュースデータを取得します。",
                        "購読機能を使う場合、Apple と RevenueCat が購入、購入の復元、購読権限状態を処理します。",
                        "Premium 要約稿サービスが有効な場合、app は設定された rewrite サービスへ言語別の要約ニュース feed を要求することがあります。",
                        "AI 読み上げを使う場合、選択したニュース本文、言語、読書年齢、音声設定が設定済みの音声サービスへ送信されます。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "現在していないこと",
                    paragraphs: [
                        "現行版には子ども向けの公開 SNS 投稿、公開チャット、パーソナライズ広告、app 内アカウント登録機能はありません。",
                        "基本機能のために連絡先、カメラ、写真、マイク、正確な位置情報の権限を積極的に要求していません。"
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "保存期間と管理",
                    paragraphs: [
                        "app を削除すると、端末に保存されたローカルデータは削除されます。",
                        "Premium 権限が終了した場合、Premium library に関連するローカルのアーカイブや保存記事データが削除されることがあります。"
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "Apple App Privacy Details 公式ページ", urlString: applePrivacyDetailsURL),
                LegalDocumentLink(title: "Apple Standard EULA 公式リンク", urlString: appleStandardEULAURL)
            ]
        )
    ]

    private static let englishDocuments: [LegalDocumentContent] = [
        LegalDocumentContent(
            title: "COPPA & Child Privacy Notice",
            introduction: "JuniorGlobe is designed to help children read world news in a kid-friendly way. Payments, restore purchases, and parent-only reports are placed behind a parent gate, and the current version aims to minimize collection of children's personal information.",
            sections: [
                LegalDocumentSectionContent(
                    title: "How the app reduces child data collection",
                    paragraphs: [
                        "The current version does not ask children to create accounts, publish profiles, upload photos, post publicly, or join chats.",
                        "Core reading features do not require contacts, camera, photo library, microphone, or precise location permissions."
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "When data may be transmitted",
                    paragraphs: [
                        "When the app connects to news sources, Apple purchase flows, RevenueCat subscription services, or app-configured backend services, those services may process IP address and standard request metadata as part of normal network operation.",
                        "When AI read-aloud is used, the selected story text, language, reading age, and voice settings are sent to the app's configured narration service to generate audio."
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "Parent rights and contact",
                    paragraphs: [
                        "Parents can contact the developer using the support email at the bottom of this page with questions about child privacy, billing, or data handling.",
                        "If a parent does not want story text sent to a remote narration service, the AI read-aloud feature should not be used."
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "FTC COPPA Official Page", urlString: coppaURL),
                LegalDocumentLink(title: "Apple App Privacy Details", urlString: applePrivacyDetailsURL)
            ]
        ),
        LegalDocumentContent(
            title: "Apple Standard EULA",
            introduction: "If JuniorGlobe is downloaded and used through the App Store, use of the app is also subject to Apple's Licensed Application End User License Agreement.",
            sections: [
                LegalDocumentSectionContent(
                    title: "How it applies",
                    paragraphs: [
                        "Unless the app later provides a custom end user license agreement, JuniorGlobe currently relies on Apple's standard App Store license terms.",
                        "For scope of license, external services, disclaimers, limitation of liability, and governing law, the Apple document controls."
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "Relation to this app",
                    paragraphs: [
                        "JuniorGlobe connects to news sources, subscription services, and remote narration services, so availability of external services may affect content and read-aloud features.",
                        "App Store purchase, refund, and device-use rules remain governed by Apple's store terms and processes."
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "Apple Standard EULA", urlString: appleStandardEULAURL)
            ]
        ),
        LegalDocumentContent(
            title: "Privacy Policy",
            introduction: "This policy describes the data handling that exists in the current version of JuniorGlobe. It does not cover features that have not shipped.",
            sections: [
                LegalDocumentSectionContent(
                    title: "Data stored on device",
                    paragraphs: [
                        "Language/edition preferences and reading-age preferences are stored in UserDefaults on the device.",
                        "Premium saved stories, the 30-day archive, and parent weekly-report data are stored locally on device, and the weekly report is generated from that local data.",
                        "AI narration audio files can be cached on device to reduce wait time for replay, and older cached files are pruned automatically."
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "Data requested over the network",
                    paragraphs: [
                        "The app fetches RSS or story data from trusted news sources.",
                        "If subscription features are used, Apple and RevenueCat process purchase, restore-purchase, and entitlement-status information.",
                        "If Premium rewritten briefs are enabled, the app may request rewritten story feeds from the configured rewrite service.",
                        "If AI read-aloud is used, the app sends the selected story text, language, reading age, and voice settings to the configured narration service."
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "What the current version does not do",
                    paragraphs: [
                        "The current version does not include child-facing social posting, public chat, personalized advertising, or in-app account registration.",
                        "The app does not actively request contacts, camera, photo library, microphone, or precise location permissions for its core reading features."
                    ]
                ),
                LegalDocumentSectionContent(
                    title: "Retention and controls",
                    paragraphs: [
                        "Deleting the app removes the local data stored on the device.",
                        "If Premium access ends, locally stored archive and saved-story data tied to Premium library features may be cleared from the device."
                    ]
                )
            ],
            links: [
                LegalDocumentLink(title: "Apple App Privacy Details", urlString: applePrivacyDetailsURL),
                LegalDocumentLink(title: "Apple Standard EULA", urlString: appleStandardEULAURL)
            ]
        )
    ]
}

extension AppEdition {
    var palette: EditionPalette {
        switch self {
        case .unitedStatesEn:
            return EditionPalette(
                heroColors: [
                    Color(red: 0.19, green: 0.52, blue: 0.78),
                    Color(red: 0.52, green: 0.77, blue: 0.86)
                ],
                lightBackgroundColors: [
                    Color(red: 0.98, green: 0.99, blue: 0.96),
                    Color(red: 0.9, green: 0.97, blue: 0.99)
                ],
                darkBackgroundColors: [
                    Color(red: 0.07, green: 0.12, blue: 0.18),
                    Color(red: 0.11, green: 0.2, blue: 0.26)
                ],
                accent: Color(red: 0.21, green: 0.58, blue: 0.82),
                secondaryAccent: Color(red: 0.98, green: 0.64, blue: 0.42)
            )
        case .taiwanZhHant:
            return EditionPalette(
                heroColors: [
                    Color(red: 0.13, green: 0.53, blue: 0.56),
                    Color(red: 0.46, green: 0.78, blue: 0.58)
                ],
                lightBackgroundColors: [
                    Color(red: 0.98, green: 1.0, blue: 0.96),
                    Color(red: 0.92, green: 0.98, blue: 0.93)
                ],
                darkBackgroundColors: [
                    Color(red: 0.05, green: 0.13, blue: 0.16),
                    Color(red: 0.09, green: 0.2, blue: 0.2)
                ],
                accent: Color(red: 0.22, green: 0.65, blue: 0.57),
                secondaryAccent: Color(red: 0.98, green: 0.73, blue: 0.3)
            )
        case .japanJa:
            return EditionPalette(
                heroColors: [
                    Color(red: 0.85, green: 0.45, blue: 0.57),
                    Color(red: 0.98, green: 0.68, blue: 0.47)
                ],
                lightBackgroundColors: [
                    Color(red: 1.0, green: 0.97, blue: 0.96),
                    Color(red: 0.98, green: 0.93, blue: 0.95)
                ],
                darkBackgroundColors: [
                    Color(red: 0.14, green: 0.08, blue: 0.11),
                    Color(red: 0.22, green: 0.11, blue: 0.15)
                ],
                accent: Color(red: 0.89, green: 0.46, blue: 0.55),
                secondaryAccent: Color(red: 0.43, green: 0.61, blue: 0.82)
            )
        }
    }

    var strings: EditionStrings {
        EditionStrings(edition: self)
    }

    func shortLabel(in presentingEdition: AppEdition) -> String {
        switch presentingEdition {
        case .taiwanZhHant:
            switch self {
            case .taiwanZhHant:
                return "台灣"
            case .japanJa:
                return "日本"
            case .unitedStatesEn:
                return "美國"
            }
        case .japanJa:
            switch self {
            case .taiwanZhHant:
                return "台湾"
            case .japanJa:
                return "日本"
            case .unitedStatesEn:
                return "アメリカ"
            }
        case .unitedStatesEn:
            switch self {
            case .taiwanZhHant:
                return "Taiwan"
            case .japanJa:
                return "Japan"
            case .unitedStatesEn:
                return "U.S."
            }
        }
    }

    func displayName(in presentingEdition: AppEdition) -> String {
        switch presentingEdition {
        case .taiwanZhHant:
            switch self {
            case .taiwanZhHant:
                return "台灣版"
            case .japanJa:
                return "日本版"
            case .unitedStatesEn:
                return "美國版"
            }
        case .japanJa:
            switch self {
            case .taiwanZhHant:
                return "台湾版"
            case .japanJa:
                return "日本版"
            case .unitedStatesEn:
                return "アメリカ版"
            }
        case .unitedStatesEn:
            switch self {
            case .taiwanZhHant:
                return "Taiwan Edition"
            case .japanJa:
                return "Japan Edition"
            case .unitedStatesEn:
                return "U.S. Edition"
            }
        }
    }
}
