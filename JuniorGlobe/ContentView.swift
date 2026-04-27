//
//  ContentView.swift
//

import SwiftUI
import Combine
import Charts

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var newsFeedModel = NewsFeedViewModel()
    @StateObject private var premiumLibrary = PremiumLibraryViewModel()
    @StateObject private var narrationController = StoryNarrationController()
    @State private var editionSettings = EditionSettings()
    @State private var selectedAgeBand: AgeBand = .ages6to9
    @State private var parentGateUnlockedUntil: Date?
    @State private var parentGateChallenge = ParentGateChallenge.generate()
    @State private var parentGateAnswer = ""
    @State private var parentGateErrorMessage: String?
    @State private var isShowingParentGateFallback = false

    var body: some View {
        let currentEdition = editionSettings.resolvedEdition
        let palette = currentEdition.palette
        let snapshot = newsFeedModel.snapshot
        let strings = currentEdition.strings

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    heroSection(snapshot: snapshot, palette: palette, edition: currentEdition)
                    audienceSection(palette: palette, edition: currentEdition)
                    storiesSection(snapshot: snapshot, palette: palette, edition: currentEdition)
                }
                .padding(20)
            }
            .background(background(for: palette).ignoresSafeArea())
            .navigationTitle("JuniorGlobe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        settingsPage(snapshot: snapshot, palette: palette, edition: currentEdition)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel(strings.settingsLabel)
                }
            }
            .task {
                await subscriptionManager.refreshAll()
            }
            .task(id: "\(selectedAgeBand.rawValue)-\(subscriptionManager.isSubscriber)") {
                await reloadCurrentFeed(
                    edition: currentEdition,
                    includePremium: subscriptionManager.isSubscriber
                )
            }
            .refreshable {
                await subscriptionManager.refreshAll()
                await reloadCurrentFeed(
                    edition: currentEdition,
                    includePremium: subscriptionManager.isSubscriber,
                    forceRefresh: true
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                guard editionSettings.isFollowingSystem else {
                    return
                }

                editionSettings.refreshResolvedEdition()
                narrationController.stop()
            }
            .onChange(of: currentEdition.rawValue + "-\(selectedAgeBand.rawValue)") {
                narrationController.stop()
            }
            .onChange(of: currentEdition.rawValue) {
                Task {
                    await reloadCurrentFeed(
                        edition: editionSettings.resolvedEdition,
                        includePremium: subscriptionManager.isSubscriber
                    )
                }
            }
            .sheet(isPresented: $isShowingParentGateFallback) {
                parentGateSheet(edition: currentEdition)
            }
        }
    }

    private func reloadCurrentFeed(
        edition: AppEdition,
        includePremium: Bool,
        forceRefresh: Bool = false
    ) async {
        await newsFeedModel.load(
            edition: edition,
            ageBand: selectedAgeBand,
            includePremium: includePremium,
            forceRefresh: forceRefresh
        )
        syncPremiumLibrary(using: subscriptionPolicy)
    }

    private func heroSection(snapshot: FeedSnapshot, palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        return EditorialCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(strings.heroTitle)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(strings.heroSubtitle)
                            .font(.body)
                            .foregroundStyle(Color.white.opacity(0.92))
                    }

                    Spacer(minLength: 12)

                    Text(edition.shortLabel(in: edition))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white)
                }

                Text(strings.editionAgeStatus(currentEdition: edition, ageBand: selectedAgeBand))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.9))

                HStack(spacing: 10) {
                    InfoChip(title: strings.storyProgressLabel(visible: snapshot.stories.count, total: snapshot.totalAvailableStoryCount), tint: Color.white.opacity(0.2))
                    InfoChip(title: strings.todayHighlightsLabel, tint: Color.white.opacity(0.2))
                }

                if let statusText = lastUpdatedStatus {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
        } background: {
            LinearGradient(
                colors: palette.heroColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func audienceSection(palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        return EditorialCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings.readingPreferencesTitle)
                    .font(.title3.weight(.bold))

                VStack(alignment: .leading, spacing: 10) {
                    Text(strings.ageBandTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker(strings.ageBandTitle, selection: $selectedAgeBand) {
                        ForEach(AgeBand.allCases) { ageBand in
                            Text(ageBand.label(for: edition)).tag(ageBand)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(palette.accent)
                }
            }
        }
    }

    private func storiesSection(snapshot: FeedSnapshot, palette: EditionPalette, edition: AppEdition) -> some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            Text(edition.strings.storiesSectionTitle)
                .font(.title2.weight(.bold))
                .padding(.horizontal, 2)

            if newsFeedModel.isLoading && snapshot.stories.isEmpty {
                EditorialCard {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(edition.strings.loadingStoriesLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if snapshot.stories.isEmpty {
                EditorialCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "newspaper.fill")
                            .font(.title3)
                            .foregroundStyle(palette.accent)

                        Text(edition.strings.emptyStoriesTitle)
                            .font(.headline)

                        Text(edition.strings.emptyStoriesDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(snapshot.stories) { story in
                    storyCard(story, palette: palette, edition: edition)
                }
            }
        }
    }

    private func storyCard(_ story: CuratedStory, palette: EditionPalette, edition: AppEdition) -> some View {
        let copy = story.copy(for: selectedAgeBand)
        let backgroundBrief = readerFacingText(
            copy.backgroundBrief.isEmpty
            ? StoryMetadataClassifier.backgroundBrief(for: story.category, region: story.region, ageBand: selectedAgeBand, edition: edition)
            : copy.backgroundBrief,
            edition: edition
        )
        let storyBody = storyBodyText(copy: copy, edition: edition, showsExpandedContent: subscriptionPolicy.showsExpandedStoryContent)
        let strings = edition.strings
        let usesStorybookLayout = edition == .unitedStatesEn && selectedAgeBand == .ages6to9
        let narrationRequest = StoryNarrationRequest(
            id: "feed|\(edition.rawValue)|\(selectedAgeBand.rawValue)|\(story.id)",
            edition: edition,
            ageBand: selectedAgeBand,
            headline: copy.headline,
            summary: storyBody,
            backgroundBrief: subscriptionPolicy.showsExpandedNarrationSegments ? backgroundBrief : nil
        )

        return EditorialCard {
            VStack(alignment: .leading, spacing: usesStorybookLayout ? 18 : 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: usesStorybookLayout ? 12 : 10) {
                        HStack(spacing: 8) {
                            InfoChip(title: story.region.label(for: edition), tint: categoryColor(for: story.category).opacity(0.14), foreground: categoryColor(for: story.category))
                            InfoChip(title: story.category.label(for: edition), tint: categoryColor(for: story.category).opacity(0.14), foreground: categoryColor(for: story.category))

                            if story.premiumOnly {
                                InfoChip(
                                    title: story.isPremiumRewrite ? strings.premiumRewriteChipTitle : strings.premiumChipTitle,
                                    tint: palette.accent.opacity(0.14),
                                    foreground: palette.accent
                                )
                            }
                        }

                        NewsHeadlineView(
                            headline: copy.headline,
                            edition: edition
                        )
                        .layoutPriority(1)
                        .padding(.top, usesStorybookLayout ? 4 : 0)

                        if story.isPremiumRewrite {
                            premiumRewriteNotice(
                                strings: strings,
                                palette: palette,
                                usesStorybookLayout: usesStorybookLayout
                            )
                        }
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 10) {
                        Text(strings.minutesLabel(copy.readingMinutes))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(elevatedPillBackground, in: Capsule())

                        if subscriptionPolicy.allowsFavorites {
                            Button {
                                premiumLibrary.toggleFavorite(
                                    story,
                                    edition: edition,
                                    ageBand: selectedAgeBand
                                )
                            } label: {
                                Image(systemName: premiumLibrary.isFavorite(story, edition: edition, ageBand: selectedAgeBand) ? "bookmark.fill" : "bookmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(palette.accent.opacity(isDarkMode ? 0.18 : 0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(strings.bookmarkAccessibilityLabel)
                        }
                    }
                }

                storySummaryBlock(
                    storyBody,
                    requestID: narrationRequest.id,
                    edition: edition,
                    palette: palette,
                    usesStorybookLayout: usesStorybookLayout
                )

                if subscriptionPolicy.showsBackgroundBrief || subscriptionPolicy.showsThinkingPrompt {
                    premiumStoryLens(
                        copy: copy,
                        backgroundBrief: backgroundBrief,
                        whyItMatters: readerFacingText(copy.whyItMatters, edition: edition),
                        narrationRequestID: narrationRequest.id,
                        palette: palette,
                        edition: edition
                    )
                }

                storySourceBlock(
                    story,
                    edition: edition,
                    palette: palette,
                    usesStorybookLayout: usesStorybookLayout
                )

                if edition.readingSupport.readAloudEnabled && subscriptionPolicy.allowsStoryNarration {
                    narrationButton(
                        request: narrationRequest,
                        palette: palette,
                        appEdition: edition
                    )
                }
            }
        } background: {
            if usesStorybookLayout {
                storybookCardBackground(palette: palette)
            }
        }
    }

    @ViewBuilder
    private func premiumRewriteNotice(
        strings: EditionStrings,
        palette: EditionPalette,
        usesStorybookLayout: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.accent)
                .padding(.top, 1)

            Text(strings.premiumRewriteDetail)
                .font(usesStorybookLayout ? .subheadline.weight(.medium) : .footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, usesStorybookLayout ? 14 : 12)
        .padding(.vertical, usesStorybookLayout ? 12 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: usesStorybookLayout ? 20 : 16, style: .continuous)
                .fill(isDarkMode ? palette.accent.opacity(0.14) : palette.accent.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: usesStorybookLayout ? 20 : 16, style: .continuous)
                .stroke(
                    isDarkMode ? palette.accent.opacity(0.24) : palette.accent.opacity(0.16),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func storySummaryBlock(
        _ summary: String,
        requestID: String,
        edition: AppEdition,
        palette: EditionPalette,
        usesStorybookLayout: Bool
    ) -> some View {
        if usesStorybookLayout {
            NarrationSentenceText(
                text: summary,
                edition: edition,
                requestID: requestID,
                segment: .summary,
                activeHighlight: narrationController.activeHighlight,
                baseColor: .primary.opacity(0.9),
                highlightTextColor: .primary,
                highlightBackgroundColor: palette.secondaryAccent.opacity(isDarkMode ? 0.26 : 0.18)
            )
                .font(.system(.title3, design: .rounded).weight(.medium))
                .lineSpacing(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isDarkMode ? Color.white.opacity(0.06) : Color.white.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            isDarkMode ? Color.white.opacity(0.08) : palette.secondaryAccent.opacity(0.12),
                            lineWidth: 1
                        )
                )
        } else {
            NarrationSentenceText(
                text: summary,
                edition: edition,
                requestID: requestID,
                segment: .summary,
                activeHighlight: narrationController.activeHighlight,
                baseColor: .primary.opacity(0.88),
                highlightTextColor: .primary,
                highlightBackgroundColor: palette.accent.opacity(isDarkMode ? 0.24 : 0.16)
            )
                .font(.body)
        }
    }

    @ViewBuilder
    private func storySourceBlock(
        _ story: CuratedStory,
        edition: AppEdition,
        palette: EditionPalette,
        usesStorybookLayout: Bool
    ) -> some View {
        if usesStorybookLayout {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(palette.secondaryAccent.opacity(isDarkMode ? 0.5 : 0.18))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(story.source.name)
                        .font(.subheadline.weight(.semibold))

                    Text("\(story.source.localizedCountryLabel(for: edition)) ・ \(story.source.localizedAuthorityLabel(for: edition))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isDarkMode ? Color.black.opacity(0.18) : palette.accent.opacity(0.06))
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.source.name)
                    .font(.subheadline.weight(.semibold))

                Text("\(story.source.localizedCountryLabel(for: edition)) ・ \(story.source.localizedAuthorityLabel(for: edition))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func storybookCardBackground(palette: EditionPalette) -> some View {
        ZStack {
            LinearGradient(
                colors: isDarkMode
                    ? [
                        palette.accent.opacity(0.16),
                        palette.secondaryAccent.opacity(0.1)
                    ]
                    : [
                        palette.accent.opacity(0.08),
                        palette.secondaryAccent.opacity(0.05)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(isDarkMode ? 0.14 : 0.08))
                .frame(width: 120, height: 120)
                .offset(x: 110, y: -80)

            Circle()
                .fill(palette.secondaryAccent.opacity(isDarkMode ? 0.12 : 0.06))
                .frame(width: 92, height: 92)
                .offset(x: -120, y: 96)
        }
    }

    @ViewBuilder
    private func premiumStoryLens(
        copy: StoryCopy,
        backgroundBrief: String,
        whyItMatters: String,
        narrationRequestID: String,
        palette: EditionPalette,
        edition: AppEdition
    ) -> some View {
        let strings = edition.strings
        let cleanedPrompt = readerFacingText(copy.talkPrompt, edition: edition)

        VStack(alignment: .leading, spacing: 10) {
            if subscriptionPolicy.showsWhyItMatters, whyItMatters.isEmpty == false {
                LensRow(
                    title: strings.whyItMattersTitle,
                    detail: whyItMatters,
                    icon: "sparkles.rectangle.stack.fill",
                    tint: palette.accent
                )
            }

            if subscriptionPolicy.showsBackgroundBrief, backgroundBrief.isEmpty == false {
                NarrationLensRow(
                    title: strings.backgroundBriefTitle,
                    detail: backgroundBrief,
                    requestID: narrationRequestID,
                    segment: .backgroundBrief,
                    edition: edition,
                    activeHighlight: narrationController.activeHighlight,
                    icon: "books.vertical.fill",
                    tint: palette.secondaryAccent,
                    highlightBackgroundColor: palette.secondaryAccent.opacity(isDarkMode ? 0.24 : 0.16)
                )
            }

            if subscriptionPolicy.showsThinkingPrompt, cleanedPrompt.isEmpty == false {
                LensRow(
                    title: strings.thinkingPromptTitle,
                    detail: cleanedPrompt,
                    icon: "questionmark.bubble.fill",
                    tint: palette.accent
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func editionSettingsSection(palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings
        let systemEdition = AppEdition.resolve(systemLocale: Locale.autoupdatingCurrent)

        return EditorialCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings.editionSettingsTitle)
                    .font(.title3.weight(.bold))

                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        editionSettings.isFollowingSystem
                            ? strings.followSystemDetail(systemEdition: systemEdition)
                            : strings.manualEditionSavedDetail(currentEdition: editionSettings.resolvedEdition)
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(strings.chooseEditionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker(strings.chooseEditionTitle, selection: Binding(
                        get: { editionSettings.resolvedEdition },
                        set: { newEdition in
                            if editionSettings.isFollowingSystem && newEdition == systemEdition {
                                return
                            }

                            editionSettings.selectManualEdition(newEdition)
                        }
                    )) {
                        ForEach(AppEdition.allCases) { option in
                            Text(option.displayName(in: edition)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(palette.accent)
                }

                if editionSettings.isFollowingSystem == false {
                    Button {
                        editionSettings.followSystem()
                    } label: {
                        Text(strings.useSystemDefaultButtonTitle)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func premiumSection(snapshot: FeedSnapshot, palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        EditorialCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings.subscriptionTitle)
                    .font(.title3.weight(.bold))

                if subscriptionManager.isSubscriber {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(strings.premiumEnabledTitle, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(palette.accent)

                        Text(strings.premiumBenefitsSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(strings.freeSummary(visibleStories: snapshot.stories.count, totalStories: snapshot.totalAvailableStoryCount))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(strings.unlockSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if subscriptionManager.isSubscriber == false {
                    parentalGateSection(palette: palette, edition: edition)
                }

                if let message = subscriptionManager.storeErrorMessage {
                    Text(message.isEmpty ? "目前暫時無法顯示訂閱方案。" : "目前暫時無法顯示訂閱方案，請稍後再試。")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if subscriptionManager.isLoadingOfferings {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(strings.loadingOfferingsLabel)
                            .foregroundStyle(.secondary)
                    }
                } else if subscriptionManager.availablePackages.isEmpty {
                    Text(strings.noPlansAvailableLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if isParentGateUnlocked {
                    Label(strings.parentGateUnlockedLabel, systemImage: "lock.open.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.accent)

                    ForEach(subscriptionManager.availablePackages) { package in
                        packageCard(package, palette: palette, edition: edition)
                    }
                } else {
                    Text(strings.parentGatePlansHiddenLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func parentalGateSection(palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isParentGateUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.headline)
                    .foregroundStyle(palette.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.parentGateTitle)
                        .font(.headline)

                    Text(
                        isParentGateUnlocked
                            ? strings.parentGateUnlockedDetail
                            : strings.parentGateLockedDetail
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if let parentGateErrorMessage, isParentGateUnlocked == false {
                Text(parentGateErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if isParentGateUnlocked == false {
                Button {
                    requestParentGateUnlock()
                } label: {
                    HStack {
                        Spacer()
                        Label(strings.parentGateUnlockButtonTitle, systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(palette.accent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func premiumLibrarySection(palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        return EditorialCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings.premiumLibraryTitle)
                    .font(.title3.weight(.bold))

                NavigationLink {
                    archiveLibraryPage(edition: edition)
                } label: {
                    LibraryLinkRow(
                        title: strings.archiveTitle,
                        detail: strings.archiveDetail(entryCount: premiumLibrary.archiveEntries.count),
                        status: strings.offlineReadyLabel,
                        tint: palette.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    favoriteLibraryPage(edition: edition)
                } label: {
                    LibraryLinkRow(
                        title: strings.favoritesTitle,
                        detail: strings.favoritesDetail(recordCount: premiumLibrary.favoriteRecords.count),
                        status: premiumLibrary.favoriteRecords.isEmpty ? strings.archiveStatusEmptyLabel : strings.archiveStatusReadyLabel,
                        tint: palette.secondaryAccent
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func parentWeeklyReportSection(palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        EditorialCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings.weeklyReportTitle)
                    .font(.title3.weight(.bold))

                if let report = premiumLibrary.weeklyReport {
                    Text(strings.parentReportDateRange(report))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ParentReportMetricTile(
                            title: strings.storyCountLabel(report.storyCount),
                            detail: strings.minutesLabel(report.estimatedReadingMinutes),
                            tint: palette.accent
                        )
                        ParentReportMetricTile(
                            title: strings.readingDayCountLabel(report.daysCovered),
                            detail: strings.favoriteCountLabel(report.favoriteCount),
                            tint: palette.secondaryAccent
                        )
                        ParentReportMetricTile(
                            title: strings.regionCountLabel(report.regionCount),
                            detail: strings.sourceCountLabel(report.sourceCount),
                            tint: palette.accent.opacity(0.88)
                        )
                        ParentReportMetricTile(
                            title: strings.categoryCountLabel(report.categoryCount),
                            detail: report.editionCount > 1
                                ? strings.editionCountLabel(report.editionCount)
                                : strings.ageBandCountLabel(report.ageBandCount),
                            tint: palette.secondaryAccent.opacity(0.92)
                        )
                    }

                    Text(strings.parentReportSummary(report))
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))

                    ParentWeeklyReportCategoryChart(
                        report: report,
                        palette: palette,
                        edition: edition
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text(strings.weeklyReportAnalysisTitle)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)

                        ParentReportInsightRow(
                            title: strings.weeklyReportDistributionTitle,
                            detail: strings.weeklyReportFocusSummary(report),
                            icon: "chart.pie.fill",
                            tint: palette.accent
                        )

                        ParentReportInsightRow(
                            title: strings.currentEditionTitle,
                            detail: strings.weeklyReportTrackingSummary(report),
                            icon: "globe.asia.australia.fill",
                            tint: palette.secondaryAccent
                        )
                    }

                    Text(strings.weeklyReportGuidanceTitle)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(strings.weeklyReportNextStretchSummary(report))
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.9))

                        Text(strings.parentConversationPrompt(report))
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.88))
                    }
                } else {
                    Text(strings.weeklyReportEmptyLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func settingsPage(snapshot: FeedSnapshot, palette: EditionPalette, edition: AppEdition) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                editionSettingsSection(palette: palette, edition: edition)
                premiumSection(snapshot: snapshot, palette: palette, edition: edition)
                if subscriptionPolicy.isPremium {
                    premiumLibrarySection(palette: palette, edition: edition)
                    parentWeeklyReportSection(palette: palette, edition: edition)
                }
                actionsSection(edition: edition)
                legalPrivacySection(edition: edition)
            }
            .padding(20)
        }
        .background(background(for: palette).ignoresSafeArea())
        .navigationTitle(edition.strings.settingsLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func archiveLibraryPage(edition: AppEdition) -> some View {
        let strings = edition.strings

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if premiumLibrary.archiveEntries.isEmpty {
                    EditorialCard {
                        Text(strings.archivePageEmptyLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(premiumLibrary.archiveEntries) { entry in
                        NavigationLink {
                            archiveDayPage(entry, edition: edition)
                        } label: {
                            ArchiveEntryRow(entry: entry, appEdition: edition)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(background(for: edition.palette).ignoresSafeArea())
        .navigationTitle(strings.archiveTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func archiveDayPage(_ entry: ArchivedFeedEntry, edition: AppEdition) -> some View {
        let entryPalette = entry.edition.palette
        let strings = edition.strings

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if subscriptionPolicy.allowsOfflineArchive == false {
                    premiumLockedLibraryCard(edition: edition)
                } else {
                    EditorialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dayKeyLabel(entry.dayKey))
                                .font(.title3.weight(.bold))

                            Text(strings.archiveDayHeader(edition: entry.edition, ageBand: entry.ageBand, storyCount: entry.snapshot.stories.count))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(strings.archiveDayOfflineDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(entry.snapshot.stories) { story in
                        archivedStoryCard(story, edition: entry.edition, ageBand: entry.ageBand, palette: entryPalette, appEdition: edition)
                    }
                }
            }
            .padding(20)
        }
        .background(background(for: entryPalette).ignoresSafeArea())
        .navigationTitle(dayKeyLabel(entry.dayKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func favoriteLibraryPage(edition: AppEdition) -> some View {
        let strings = edition.strings

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if subscriptionPolicy.allowsFavorites == false {
                    premiumLockedLibraryCard(edition: edition)
                } else if premiumLibrary.favoriteRecords.isEmpty {
                    EditorialCard {
                        Text(strings.favoritesPageEmptyLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(premiumLibrary.favoriteRecords) { record in
                        favoriteStoryCard(record, palette: record.edition.palette, appEdition: edition)
                    }
                }
            }
            .padding(20)
        }
        .background(background(for: edition.palette).ignoresSafeArea())
        .navigationTitle(strings.favoritesTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func premiumLockedLibraryCard(edition: AppEdition) -> some View {
        EditorialCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(edition.strings.premiumLibraryTitle)
                    .font(.headline)

                Text(edition.strings.unlockSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func packageCard(_ package: SubscriptionPackage, palette: EditionPalette, edition: AppEdition) -> some View {
        let strings = edition.strings

        return EditorialCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strings.subscriptionPackageTitle(for: package))
                            .font(.headline)
                        Text(strings.subscriptionPackageSubtitle(for: package))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(package.priceLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.accent)
                }

                Button {
                    Task {
                        _ = await subscriptionManager.purchase(package)
                    }
                } label: {
                    HStack {
                        Spacer()
                        if subscriptionManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(edition.strings.upgradePremiumButtonTitle)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .background(
                    LinearGradient(
                        colors: [palette.accent, palette.secondaryAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(.white)
                .disabled(subscriptionManager.isPurchasing || subscriptionManager.isRestoring)
            }
        }
    }

    private func actionsSection(edition: AppEdition) -> some View {
        EditorialCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(edition.strings.accountActionsTitle)
                    .font(.headline)

                if newsFeedModel.isRefreshing {
                    Label(edition.strings.refreshingStoriesLabel, systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await subscriptionManager.refreshAll()
                        await newsFeedModel.load(
                            edition: edition,
                            ageBand: selectedAgeBand,
                            includePremium: subscriptionManager.isSubscriber,
                            forceRefresh: true
                        )
                        syncPremiumLibrary(using: subscriptionPolicy)
                    }
                } label: {
                    Label(edition.strings.refreshNewsButtonTitle, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(subscriptionManager.isRefreshingStatus || subscriptionManager.isLoadingOfferings || newsFeedModel.isLoading)

                Button {
                    Task {
                        _ = await subscriptionManager.restorePurchases()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if subscriptionManager.isRestoring {
                            ProgressView()
                        } else {
                            Label(edition.strings.restorePurchasesButtonTitle, systemImage: "creditcard.and.123")
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(subscriptionManager.isPurchasing || subscriptionManager.isRestoring)
            }
        }
    }

    private func legalPrivacySection(edition: AppEdition) -> some View {
        let strings = edition.strings

        return EditorialCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(strings.legalPrivacyTitle)
                    .font(.headline)

                Text(strings.legalPrivacySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(strings.legalPrivacyLastUpdatedLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(strings.legalDocuments) { document in
                    DisclosureGroup {
                        legalDocumentBody(document)
                            .padding(.top, 8)
                    } label: {
                        Text(document.title)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.legalPrivacySupportTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(strings.legalPrivacySupportIdentity)
                        .font(.subheadline.weight(.semibold))

                    Text(strings.legalPrivacySupportSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let supportURL = URL(string: "mailto:eric1207cvb@msn.com") {
                        Link(destination: supportURL) {
                            Label("eric1207cvb@msn.com", systemImage: "envelope.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func legalDocumentBody(_ document: LegalDocumentContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(document.introduction)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.9))

            ForEach(document.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.88))
                    }
                }
            }

            if document.links.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(document.links) { link in
                        if let url = URL(string: link.urlString) {
                            Link(destination: url) {
                                Label(link.title, systemImage: "arrow.up.right.square")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
            }
        }
    }

    private func parentGateSheet(edition: AppEdition) -> some View {
        let strings = edition.strings

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(strings.parentGateFallbackTitle)
                        .font(.title3.weight(.bold))

                    Text(strings.parentGateFallbackDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(strings.parentGateFallbackPrompt(parentGateChallenge))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(edition.palette.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                        )

                    TextField(strings.parentGateFallbackPlaceholder, text: $parentGateAnswer)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    if let parentGateErrorMessage {
                        Text(parentGateErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        confirmParentGateFallback(for: edition)
                    } label: {
                        HStack {
                            Spacer()
                            Text(strings.parentGateConfirmButtonTitle)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        LinearGradient(
                            colors: [edition.palette.accent, edition.palette.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .foregroundStyle(.white)
                }
                .padding(20)
            }
            .background(background(for: edition.palette).ignoresSafeArea())
            .navigationTitle(strings.parentGateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.parentGateCancelButtonTitle) {
                        dismissParentGateFallback()
                    }
                }
            }
        }
    }

    private var lastUpdatedStatus: String? {
        guard let updatedAt = newsFeedModel.lastUpdatedAt else {
            return nil
        }
        return editionSettings.resolvedEdition.strings.lastUpdatedString(updatedAt)
    }

    private var subscriptionPolicy: SubscriptionPolicy {
        SubscriptionPolicy.current(
            isPremium: subscriptionManager.isSubscriber,
            ageBand: selectedAgeBand
        )
    }

    private func syncPremiumLibrary(using policy: SubscriptionPolicy) {
        premiumLibrary.syncCurrentFeed(
            edition: editionSettings.resolvedEdition,
            ageBand: selectedAgeBand,
            policy: policy,
            snapshot: newsFeedModel.snapshot,
            trustedSources: newsFeedModel.trustedSources,
            deliveryMode: newsFeedModel.deliveryMode,
            lastUpdatedAt: newsFeedModel.lastUpdatedAt,
            dayKey: newsFeedModel.dayKey
        )
    }

    private var isParentGateUnlocked: Bool {
        guard subscriptionManager.isSubscriber == false else {
            return true
        }

        guard let parentGateUnlockedUntil else {
            return false
        }

        return parentGateUnlockedUntil > Date()
    }

    @MainActor
    private func requestParentGateUnlock() {
        parentGateErrorMessage = nil
        presentParentGateFallback()
    }

    private func presentParentGateFallback() {
        parentGateChallenge = ParentGateChallenge.generate()
        parentGateAnswer = ""
        parentGateErrorMessage = nil
        isShowingParentGateFallback = true
    }

    private func dismissParentGateFallback() {
        isShowingParentGateFallback = false
        parentGateAnswer = ""
        parentGateErrorMessage = nil
    }

    private func confirmParentGateFallback(for edition: AppEdition) {
        let normalizedAnswer = parentGateAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAnswer == String(parentGateChallenge.answer) else {
            parentGateErrorMessage = edition.strings.parentGateFallbackErrorLabel
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            parentGateUnlockedUntil = Date().addingTimeInterval(10 * 60)
            isShowingParentGateFallback = false
        }
        parentGateAnswer = ""
        parentGateErrorMessage = nil
    }

    private func grantParentGateAccess() {
        parentGateUnlockedUntil = Date().addingTimeInterval(10 * 60)
        parentGateErrorMessage = nil
    }

    private func archivedStoryCard(
        _ story: CuratedStory,
        edition: AppEdition,
        ageBand: AgeBand,
        palette: EditionPalette,
        appEdition: AppEdition
    ) -> some View {
        let copy = story.copy(for: ageBand)
        let backgroundBrief = readerFacingText(
            copy.backgroundBrief.isEmpty
            ? StoryMetadataClassifier.backgroundBrief(for: story.category, region: story.region, ageBand: ageBand, edition: edition)
            : copy.backgroundBrief,
            edition: edition
        )
        let storyBody = storyBodyText(copy: copy, edition: edition, showsExpandedContent: true)
        let narrationRequest = StoryNarrationRequest(
            id: "archive|\(edition.rawValue)|\(ageBand.rawValue)|\(story.id)",
            edition: edition,
            ageBand: ageBand,
            headline: copy.headline,
            summary: storyBody,
            backgroundBrief: backgroundBrief
        )

        return EditorialCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    InfoChip(title: story.region.label(for: appEdition), tint: categoryColor(for: story.category).opacity(0.14), foreground: categoryColor(for: story.category))
                    InfoChip(title: story.category.label(for: appEdition), tint: categoryColor(for: story.category).opacity(0.14), foreground: categoryColor(for: story.category))
                }

                NewsHeadlineView(headline: copy.headline, edition: edition)

                NarrationSentenceText(
                    text: storyBody,
                    edition: edition,
                    requestID: narrationRequest.id,
                    segment: .summary,
                    activeHighlight: narrationController.activeHighlight,
                    baseColor: .primary.opacity(0.88),
                    highlightTextColor: .primary,
                    highlightBackgroundColor: palette.accent.opacity(isDarkMode ? 0.24 : 0.16)
                )
                    .font(.body)

                premiumArchiveLens(
                    backgroundBrief: backgroundBrief,
                    whyItMatters: readerFacingText(copy.whyItMatters, edition: edition),
                    talkPrompt: readerFacingText(copy.talkPrompt, edition: edition),
                    narrationRequestID: narrationRequest.id,
                    palette: palette,
                    edition: appEdition,
                    contentEdition: edition
                )

                Text(story.source.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if edition.readingSupport.readAloudEnabled {
                    narrationButton(
                        request: narrationRequest,
                        palette: palette,
                        appEdition: appEdition
                    )
                }
            }
        }
    }

    private func favoriteStoryCard(_ record: FavoriteStoryRecord, palette: EditionPalette, appEdition: AppEdition) -> some View {
        let copy = record.story.copy(for: record.ageBand)
        let backgroundBrief = readerFacingText(
            copy.backgroundBrief.isEmpty
            ? StoryMetadataClassifier.backgroundBrief(for: record.story.category, region: record.story.region, ageBand: record.ageBand, edition: record.edition)
            : copy.backgroundBrief,
            edition: record.edition
        )
        let storyBody = storyBodyText(copy: copy, edition: record.edition, showsExpandedContent: true)
        let strings = appEdition.strings
        let narrationRequest = StoryNarrationRequest(
            id: "favorite|\(record.edition.rawValue)|\(record.ageBand.rawValue)|\(record.story.id)",
            edition: record.edition,
            ageBand: record.ageBand,
            headline: copy.headline,
            summary: storyBody,
            backgroundBrief: backgroundBrief
        )

        return EditorialCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.edition.displayName(in: appEdition) + " ・ " + record.ageBand.label(for: appEdition))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        NewsHeadlineView(headline: copy.headline, edition: record.edition)
                    }

                    Spacer(minLength: 12)

                    Button(role: .destructive) {
                        premiumLibrary.removeFavorite(recordID: record.id)
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(palette.accent)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(palette.accent.opacity(isDarkMode ? 0.18 : 0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(strings.removeFavoriteAccessibilityLabel)
                }

                NarrationSentenceText(
                    text: storyBody,
                    edition: record.edition,
                    requestID: narrationRequest.id,
                    segment: .summary,
                    activeHighlight: narrationController.activeHighlight,
                    baseColor: .primary.opacity(0.88),
                    highlightTextColor: .primary,
                    highlightBackgroundColor: palette.accent.opacity(isDarkMode ? 0.24 : 0.16)
                )
                    .font(.body)

                premiumArchiveLens(
                    backgroundBrief: backgroundBrief,
                    whyItMatters: readerFacingText(copy.whyItMatters, edition: record.edition),
                    talkPrompt: readerFacingText(copy.talkPrompt, edition: record.edition),
                    narrationRequestID: narrationRequest.id,
                    palette: palette,
                    edition: appEdition,
                    contentEdition: record.edition
                )

                Text(strings.savedAtLabel(record.savedAt))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if record.edition.readingSupport.readAloudEnabled {
                    narrationButton(
                        request: narrationRequest,
                        palette: palette,
                        appEdition: appEdition
                    )
                }
            }
        }
    }

    private func narrationButton(
        request: StoryNarrationRequest,
        palette: EditionPalette,
        appEdition: AppEdition
    ) -> some View {
        let status = narrationController.status(for: request.id)
        let isPreparing = status?.isPreparing == true
        let strings = appEdition.strings

        return Button {
            narrationController.toggleNarration(for: request)
        } label: {
            VStack(alignment: .leading, spacing: (isPreparing || status?.failureReason != nil) ? 8 : 0) {
                HStack(spacing: 10) {
                    Image(systemName: narrationSymbolName(for: status))
                        .font(.headline)

                    Text(strings.narrationButtonTitle(for: status))
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    if let status, isPreparing {
                        Text("\(Int(status.normalizedProgress * 100))%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if let status, isPreparing {
                    narrationProgressStages(
                        status: status,
                        strings: strings,
                        palette: palette
                    )

                    ProgressView(value: status.normalizedProgress)
                        .tint(palette.accent)

                    Text(strings.narrationProgressLabel(for: status.stage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(strings.narrationProgressDetail(for: status.stage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let failureReason = status?.failureReason {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(strings.narrationFailureMessage(for: failureReason), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(strings.narrationFailureRecoveryHint(for: failureReason))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : palette.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isDarkMode ? Color.white.opacity(0.08) : palette.accent.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.accent)
        .accessibilityLabel(strings.narrationAccessibilityLabel(status: status))
    }

    @ViewBuilder
    private func narrationProgressStages(
        status: StoryNarrationStatus,
        strings: EditionStrings,
        palette: EditionPalette
    ) -> some View {
        HStack(spacing: 8) {
            narrationStageChip(
                title: strings.narrationStageShortLabel(for: .requestingScript),
                state: narrationStageState(target: .requestingScript, current: status.stage),
                palette: palette
            )
            narrationStageChip(
                title: strings.narrationStageShortLabel(for: .generatingAudio),
                state: narrationStageState(target: .generatingAudio, current: status.stage),
                palette: palette
            )
            narrationStageChip(
                title: strings.narrationStageShortLabel(for: .preparingPlayback),
                state: narrationStageState(target: .preparingPlayback, current: status.stage),
                palette: palette
            )
        }
    }

    private func narrationStageChip(
        title: String,
        state: NarrationStageVisualState,
        palette: EditionPalette
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: state.symbolName)
                .font(.caption2.weight(.bold))

            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(state.backgroundColor(isDarkMode: isDarkMode, palette: palette))
        )
        .foregroundStyle(state.foregroundColor(isDarkMode: isDarkMode, palette: palette))
    }

    private func narrationStageState(
        target: StoryNarrationStage,
        current: StoryNarrationStage
    ) -> NarrationStageVisualState {
        guard let targetRank = narrationStageRank(for: target),
              let currentRank = narrationStageRank(for: current) else {
            return .idle
        }

        if targetRank < currentRank {
            return .completed
        }

        if targetRank == currentRank {
            return .current
        }

        return .idle
    }

    private func narrationStageRank(for stage: StoryNarrationStage) -> Int? {
        switch stage {
        case .requestingScript:
            return 0
        case .generatingAudio:
            return 1
        case .preparingPlayback:
            return 2
        case .playing, .failed:
            return nil
        }
    }

    private func narrationSymbolName(for status: StoryNarrationStatus?) -> String {
        guard let status else {
            return "play.circle.fill"
        }

        switch status.stage {
        case .requestingScript:
            return "text.bubble.fill"
        case .generatingAudio:
            return "waveform.circle.fill"
        case .preparingPlayback:
            return "arrow.down.circle.fill"
        case .playing:
            return "stop.circle.fill"
        case .failed:
            return "arrow.clockwise.circle.fill"
        }
    }

    private func premiumArchiveLens(
        backgroundBrief: String,
        whyItMatters: String,
        talkPrompt: String,
        narrationRequestID: String,
        palette: EditionPalette,
        edition: AppEdition,
        contentEdition: AppEdition
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if whyItMatters.isEmpty == false {
                LensRow(
                    title: edition.strings.whyItMattersTitle,
                    detail: whyItMatters,
                    icon: "sparkles.rectangle.stack.fill",
                    tint: palette.accent
                )
            }

            if backgroundBrief.isEmpty == false {
                NarrationLensRow(
                    title: edition.strings.backgroundBriefTitle,
                    detail: backgroundBrief,
                    requestID: narrationRequestID,
                    segment: .backgroundBrief,
                    edition: contentEdition,
                    activeHighlight: narrationController.activeHighlight,
                    icon: "books.vertical.fill",
                    tint: palette.secondaryAccent,
                    highlightBackgroundColor: palette.secondaryAccent.opacity(isDarkMode ? 0.24 : 0.16)
                )
            }

            if talkPrompt.isEmpty == false {
                LensRow(
                    title: edition.strings.thinkingPromptTitle,
                    detail: talkPrompt,
                    icon: "questionmark.bubble.fill",
                    tint: palette.accent
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func storyBodyText(copy: StoryCopy, edition: AppEdition, showsExpandedContent: Bool) -> String {
        let cleanedSummary = readerFacingText(copy.summary, edition: edition)
        let cleanedGuide = readerFacingText(copy.understandingGuide, edition: edition)

        guard showsExpandedContent, cleanedGuide.isEmpty == false else {
            return cleanedSummary
        }

        guard cleanedSummary.isEmpty == false else {
            return cleanedGuide
        }

        return cleanedSummary + "\n\n" + cleanedGuide
    }

    private func readerFacingText(_ text: String, edition: AppEdition) -> String {
        ReaderFacingTextSanitizer.clean(text, language: edition.contentLanguage)
    }

    private func dayKeyLabel(_ dayKey: String) -> String {
        editionSettings.resolvedEdition.strings.dayLabel(for: dayKey)
    }

    private func background(for palette: EditionPalette) -> some View {
        let backgroundColors = isDarkMode ? palette.darkBackgroundColors : palette.lightBackgroundColors

        return ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(isDarkMode ? 0.24 : 0.18),
                            palette.accent.opacity(isDarkMode ? 0.08 : 0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 150
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 110, y: -260)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.secondaryAccent.opacity(isDarkMode ? 0.22 : 0.16),
                            palette.secondaryAccent.opacity(isDarkMode ? 0.08 : 0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 180
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: -140, y: 280)
        }
    }

    private func categoryColor(for category: StoryCategory) -> Color {
        switch category {
        case .science:
            return Color(red: 0.19, green: 0.48, blue: 0.82)
        case .climate:
            return Color(red: 0.17, green: 0.58, blue: 0.38)
        case .culture:
            return Color(red: 0.72, green: 0.34, blue: 0.19)
        case .civics:
            return Color(red: 0.58, green: 0.34, blue: 0.72)
        case .innovation:
            return Color(red: 0.85, green: 0.46, blue: 0.14)
        }
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    private var elevatedPillBackground: Color {
        isDarkMode
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.07)
    }
}

struct ParentGateChallenge: Equatable {
    enum Operation: CaseIterable, Equatable {
        case addition
        case subtraction

        var symbol: String {
            switch self {
            case .addition:
                return "+"
            case .subtraction:
                return "-"
            }
        }
    }

    let firstNumber: Int
    let secondNumber: Int
    let operation: Operation

    var answer: Int {
        switch operation {
        case .addition:
            return firstNumber + secondNumber
        case .subtraction:
            return firstNumber - secondNumber
        }
    }

    static func generate() -> ParentGateChallenge {
        let operation = Operation.allCases.randomElement() ?? .addition

        switch operation {
        case .addition:
            return ParentGateChallenge(
                firstNumber: Int.random(in: 12...29),
                secondNumber: Int.random(in: 3...9),
                operation: .addition
            )
        case .subtraction:
            let secondNumber = Int.random(in: 3...9)
            return ParentGateChallenge(
                firstNumber: Int.random(in: max(12, secondNumber + 4)...29),
                secondNumber: secondNumber,
                operation: .subtraction
            )
        }
    }
}

private struct NarrationSentenceText: View {
    let text: String
    let edition: AppEdition
    let requestID: String
    let segment: StoryNarrationSegment
    let activeHighlight: StoryNarrationHighlight?
    let baseColor: Color
    let highlightTextColor: Color
    let highlightBackgroundColor: Color

    var body: some View {
        if usesFastPath {
            Text(text)
                .foregroundStyle(baseColor)
        } else {
            Text(attributedText)
        }
    }

    private var attributedText: AttributedString {
        let sentences = StoryNarrationController.sentences(
            in: text,
            edition: edition,
            segment: segment
        )

        guard sentences.isEmpty == false else {
            var fallback = AttributedString(text)
            fallback.foregroundColor = baseColor
            return fallback
        }

        var output = AttributedString()

        for (offset, sentence) in sentences.enumerated() {
            var fragment = AttributedString(sentence.text)
            fragment.foregroundColor = isActive(sentence) ? highlightTextColor : baseColor

            if isActive(sentence) {
                fragment.backgroundColor = highlightBackgroundColor
            }

            output += fragment

            let separator = separator(after: offset, total: sentences.count)
            if separator.isEmpty == false {
                var spacer = AttributedString(separator)
                spacer.foregroundColor = baseColor
                output += spacer
            }
        }

        return output
    }

    private var usesFastPath: Bool {
        activeHighlight?.requestID != requestID || activeHighlight?.segment != segment
    }

    private func isActive(_ sentence: StoryNarrationSentence) -> Bool {
        activeHighlight?.requestID == requestID &&
        activeHighlight?.segment == segment &&
        activeHighlight?.sentenceIndex == sentence.index
    }

    private func separator(after offset: Int, total: Int) -> String {
        guard offset < total - 1 else {
            return ""
        }

        switch edition.contentLanguage {
        case .traditionalChinese, .japanese:
            return ""
        case .english:
            return " "
        }
    }
}

private struct NarrationLensRow: View {
    let title: String
    let detail: String
    let requestID: String
    let segment: StoryNarrationSegment
    let edition: AppEdition
    let activeHighlight: StoryNarrationHighlight?
    let icon: String
    let tint: Color
    let highlightBackgroundColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)

                NarrationSentenceText(
                    text: detail,
                    edition: edition,
                    requestID: requestID,
                    segment: segment,
                    activeHighlight: activeHighlight,
                    baseColor: .primary.opacity(0.9),
                    highlightTextColor: .primary,
                    highlightBackgroundColor: highlightBackgroundColor
                )
                .font(.subheadline)
            }
        }
    }
}

private struct EditorialCard<Content: View, Background: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content
    private let background: Background

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder background: () -> Background = { Color.clear }
    ) {
        self.content = content()
        self.background = background()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardFill)
                background
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 12, x: 0, y: 5)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.1, green: 0.12, blue: 0.16).opacity(0.96)
            : Color.white.opacity(0.78)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.26)
            : Color.black.opacity(0.05)
    }
}

private struct InfoChip: View {
    let title: String
    let tint: Color
    let foreground: Color

    init(title: String, tint: Color, foreground: Color = .white) {
        self.title = title
        self.tint = tint
        self.foreground = foreground
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
            .foregroundStyle(foreground)
    }
}

private struct ParentReportMetricTile: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct ParentReportInsightRow: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.9))
            }
        }
    }
}

private struct ParentWeeklyReportCategoryChart: View {
    @Environment(\.colorScheme) private var colorScheme

    let report: ParentWeeklyReport
    let palette: EditionPalette
    let edition: AppEdition

    var body: some View {
        let strings = edition.strings

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(strings.weeklyReportDistributionTitle)
                    .font(.headline)

                Text(strings.weeklyReportDistributionDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Chart(report.categoryDistribution) { slice in
                    SectorMark(
                        angle: .value("Stories", slice.storyCount),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(color(for: slice.category))
                    .cornerRadius(6)
                }
                .chartLegend(.hidden)
                .frame(height: 220)

                VStack(spacing: 4) {
                    if let dominantCategory = report.dominantCategory {
                        Text(dominantCategory.label(for: edition))
                            .font(.headline.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(strings.shareLabel(report.categoryDistribution.first?.share ?? 0))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(strings.storyCountLabel(report.storyCount))
                            .font(.headline.weight(.bold))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.16) : Color.white.opacity(0.82))
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(report.categoryDistribution) { slice in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(color(for: slice.category))
                            .frame(width: 10, height: 10)

                        Text(slice.category.label(for: edition))
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(strings.categoryDistributionDetailLabel(storyCount: slice.storyCount, share: slice.share))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func color(for category: StoryCategory) -> Color {
        switch category {
        case .science:
            return palette.accent
        case .climate:
            return Color(red: 0.26, green: 0.66, blue: 0.44)
        case .culture:
            return palette.secondaryAccent
        case .civics:
            return Color(red: 0.85, green: 0.42, blue: 0.33)
        case .innovation:
            return Color(red: 0.44, green: 0.49, blue: 0.86)
        }
    }
}

private struct LibraryLinkRow: View {
    let title: String
    let detail: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 8) {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ArchiveEntryRow: View {
    let entry: ArchivedFeedEntry
    let appEdition: AppEdition

    var body: some View {
        EditorialCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayLabel)
                            .font(.headline)

                        Text("\(entry.edition.displayName(in: appEdition)) ・ \(entry.ageBand.label(for: appEdition))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Text(appEdition.strings.offlineReadyLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    InfoChip(title: appEdition.strings.storyCountLabel(entry.snapshot.stories.count), tint: Color.primary.opacity(0.08), foreground: Color.primary)
                    InfoChip(title: appEdition.strings.regionCountLabel(entry.snapshot.visibleRegionCount), tint: Color.primary.opacity(0.08), foreground: Color.primary)
                    InfoChip(title: appEdition.strings.categoryCountLabel(entry.snapshot.visibleCategoryCount), tint: Color.primary.opacity(0.08), foreground: Color.primary)
                }
            }
        }
    }

    private var dayLabel: String {
        appEdition.strings.dayLabel(for: entry.dayKey)
    }
}

private enum NarrationStageVisualState {
    case idle
    case current
    case completed

    var symbolName: String {
        switch self {
        case .idle:
            return "circle.fill"
        case .current:
            return "sparkles"
        case .completed:
            return "checkmark.circle.fill"
        }
    }

    func backgroundColor(isDarkMode: Bool, palette: EditionPalette) -> Color {
        switch self {
        case .idle:
            return isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
        case .current:
            return isDarkMode ? palette.accent.opacity(0.28) : palette.accent.opacity(0.16)
        case .completed:
            return isDarkMode ? palette.secondaryAccent.opacity(0.24) : palette.secondaryAccent.opacity(0.16)
        }
    }

    func foregroundColor(isDarkMode: Bool, palette: EditionPalette) -> Color {
        switch self {
        case .idle:
            return isDarkMode ? Color.white.opacity(0.55) : Color.black.opacity(0.45)
        case .current:
            return isDarkMode ? .white : palette.accent
        case .completed:
            return isDarkMode ? .white.opacity(0.92) : palette.secondaryAccent
        }
    }
}

private struct LensRow: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.9))
            }
        }
    }
}
