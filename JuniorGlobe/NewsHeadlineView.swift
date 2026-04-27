//
//  NewsHeadlineView.swift
//  JuniorGlobe
//

import SwiftUI
import UIKit
import CoreText

struct NewsHeadlineView: UIViewRepresentable {
    let headline: String
    let edition: AppEdition

    func makeUIView(context: Context) -> MarqueeHeadlineUIView {
        MarqueeHeadlineUIView()
    }

    func updateUIView(_ uiView: MarqueeHeadlineUIView, context: Context) {
        uiView.apply(headline: headline, edition: edition)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarqueeHeadlineUIView, context: Context) -> CGSize? {
        let width = proposal.width ?? 280
        let allowScroll = UIAccessibility.isReduceMotionEnabled == false
        return CGSize(
            width: width,
            height: HeadlineLayout.preferredHeight(for: width, headline: headline, edition: edition, allowScroll: allowScroll)
        )
    }
}

private final class TextInsetsLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetBounds = bounds.inset(by: textInsets)
        let textRect = super.textRect(forBounds: insetBounds, limitedToNumberOfLines: numberOfLines)

        return CGRect(
            x: textRect.origin.x - textInsets.left,
            y: textRect.origin.y - textInsets.top,
            width: textRect.size.width + textInsets.left + textInsets.right,
            height: textRect.size.height + textInsets.top + textInsets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(
            CGSize(
                width: max(0, size.width - textInsets.left - textInsets.right),
                height: max(0, size.height - textInsets.top - textInsets.bottom)
            )
        )

        return CGSize(
            width: fitted.width + textInsets.left + textInsets.right,
            height: fitted.height + textInsets.top + textInsets.bottom
        )
    }
}

final class MarqueeHeadlineUIView: UIView {
    private let staticLabel = TextInsetsLabel()
    private let primaryLabel = TextInsetsLabel()
    private let secondaryLabel = TextInsetsLabel()
    private let fadeMaskLayer = CAGradientLayer()

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var pauseRemaining: CFTimeInterval = 0
    private var currentOffset: CGFloat = 0
    private var lastMeasuredWidth: CGFloat = 0
    private var measuredTitleSize: CGSize = .zero
    private var needsMeasurement = true
    private var shouldScroll = false
    private var currentHeadline = ""
    private var currentEdition: AppEdition = .taiwanZhHant
    private var currentStyle = HeadlineLayout.style(for: .taiwanZhHant)

    override init(frame: CGRect) {
        super.init(frame: frame)

        isAccessibilityElement = true
        accessibilityTraits = .staticText
        clipsToBounds = false
        isUserInteractionEnabled = false

        configureStaticLabel()
        configureMarqueeLabel(primaryLabel)
        configureMarqueeLabel(secondaryLabel)
        updateInsets()

        addSubview(staticLabel)
        addSubview(primaryLabel)
        addSubview(secondaryLabel)
        staticLabel.isHidden = false
        primaryLabel.isHidden = true
        secondaryLabel.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopMarquee()
    }

    func apply(headline: String, edition: AppEdition) {
        let normalizedHeadline = headline
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard currentHeadline != normalizedHeadline || currentEdition != edition else {
            return
        }

        currentHeadline = normalizedHeadline
        currentEdition = edition
        currentStyle = HeadlineLayout.style(for: edition)
        currentOffset = 0
        lastTimestamp = nil
        pauseRemaining = currentStyle.initialPause
        needsMeasurement = true
        accessibilityLabel = normalizedHeadline
        updateInsets()

        let attributed = HeadlineRubyFormatter.attributedHeadline(normalizedHeadline, edition: edition)
        staticLabel.attributedText = attributed
        primaryLabel.attributedText = attributed
        secondaryLabel.attributedText = attributed

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        if needsMeasurement || abs(lastMeasuredWidth - bounds.width) > .ulpOfOne {
            recomputeMeasurements()
            lastMeasuredWidth = bounds.width
            needsMeasurement = false
        }

        staticLabel.isHidden = shouldScroll
        primaryLabel.isHidden = shouldScroll == false
        secondaryLabel.isHidden = shouldScroll == false

        if shouldScroll {
            startMarqueeIfNeeded()
            applyFadeMask()
            clipsToBounds = true
            secondaryLabel.isHidden = false
            staticLabel.frame = .zero
        } else {
            stopMarquee()
            currentOffset = 0
            clipsToBounds = false
            layer.mask = nil
            secondaryLabel.isHidden = true
            staticLabel.frame = bounds
        }

        layoutLabelFrames()
    }

    private func recomputeMeasurements() {
        let width = max(bounds.width, 1)
        let allowScroll = UIAccessibility.isReduceMotionEnabled == false
        shouldScroll = allowScroll && HeadlineLayout.shouldScroll(for: width, headline: currentHeadline, edition: currentEdition)
        measuredTitleSize = primaryLabel.sizeThatFits(
            CGSize(width: 10_000, height: max(bounds.height, HeadlineLayout.marqueeHeight(for: currentEdition)))
        )
    }

    private func layoutLabelFrames() {
        guard shouldScroll else {
            return
        }

        let titleHeight = min(bounds.height, ceil(measuredTitleSize.height))
        let y = max(0, (bounds.height - titleHeight) / 2)
        let width = ceil(measuredTitleSize.width)

        primaryLabel.frame = CGRect(x: -currentOffset, y: y, width: width, height: titleHeight)
        secondaryLabel.frame = CGRect(
            x: primaryLabel.frame.maxX + currentStyle.marqueeSpacing,
            y: y,
            width: width,
            height: titleHeight
        )
    }

    private func configureStaticLabel() {
        staticLabel.numberOfLines = 2
        staticLabel.lineBreakMode = .byWordWrapping
        staticLabel.adjustsFontForContentSizeCategory = true
        staticLabel.backgroundColor = .clear
        staticLabel.textAlignment = .natural
        staticLabel.textInsets = currentStyle.staticTextInsets
    }

    private func configureMarqueeLabel(_ label: TextInsetsLabel) {
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.adjustsFontForContentSizeCategory = true
        label.backgroundColor = .clear
        label.textAlignment = .natural
        label.textInsets = currentStyle.marqueeTextInsets
    }

    private func startMarqueeIfNeeded() {
        guard displayLink == nil else {
            return
        }

        let displayLink = CADisplayLink(target: self, selector: #selector(stepMarquee))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stopMarquee() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    @objc
    private func stepMarquee(_ displayLink: CADisplayLink) {
        guard shouldScroll else {
            stopMarquee()
            return
        }

        if lastTimestamp == nil {
            lastTimestamp = displayLink.timestamp
            return
        }

        let delta = displayLink.timestamp - (lastTimestamp ?? displayLink.timestamp)
        lastTimestamp = displayLink.timestamp

        if pauseRemaining > 0 {
            pauseRemaining = max(0, pauseRemaining - delta)
            return
        }

        currentOffset += CGFloat(delta) * currentStyle.pointsPerSecond

        let cycleWidth = ceil(measuredTitleSize.width) + currentStyle.marqueeSpacing
        if currentOffset >= cycleWidth {
            currentOffset = 0
            pauseRemaining = currentStyle.loopPause
        }

        layoutLabelFrames()
    }

    private func applyFadeMask() {
        let fadeWidth = min(currentStyle.fadeWidth, max(12, bounds.width * 0.12))
        let startFade = NSNumber(value: Float(fadeWidth / max(bounds.width, 1)))
        let endFade = NSNumber(value: Float(1 - (fadeWidth / max(bounds.width, 1))))

        fadeMaskLayer.frame = bounds
        fadeMaskLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        fadeMaskLayer.locations = [0, startFade, endFade, 1]
        layer.mask = fadeMaskLayer
    }

    private func updateInsets() {
        staticLabel.textInsets = currentStyle.staticTextInsets
        primaryLabel.textInsets = currentStyle.marqueeTextInsets
        secondaryLabel.textInsets = currentStyle.marqueeTextInsets
    }
}

private struct HeadlineStyle {
    let font: UIFont
    let lineSpacing: CGFloat
    let rubySizeFactor: CGFloat
    let rubyLineReserve: CGFloat
    let staticTextInsets: UIEdgeInsets
    let marqueeTextInsets: UIEdgeInsets
    let maxStaticLines: Int
    let pointsPerSecond: CGFloat
    let marqueeSpacing: CGFloat
    let fadeWidth: CGFloat
    let initialPause: CFTimeInterval
    let loopPause: CFTimeInterval
}

enum HeadlineLayout {
    fileprivate nonisolated static func style(for edition: AppEdition) -> HeadlineStyle {
        switch edition {
        case .taiwanZhHant:
            return HeadlineStyle(
                font: roundedFont(size: 22, weight: .bold),
                lineSpacing: 10,
                rubySizeFactor: 0.28,
                rubyLineReserve: 16,
                staticTextInsets: UIEdgeInsets(top: 14, left: 0, bottom: 6, right: 0),
                marqueeTextInsets: UIEdgeInsets(top: 10, left: 0, bottom: 4, right: 0),
                maxStaticLines: 2,
                pointsPerSecond: 18,
                marqueeSpacing: 40,
                fadeWidth: 18,
                initialPause: 1.4,
                loopPause: 1.8
            )
        case .japanJa:
            return HeadlineStyle(
                font: roundedFont(size: 22, weight: .bold),
                lineSpacing: 6,
                rubySizeFactor: 0.26,
                rubyLineReserve: 0,
                staticTextInsets: UIEdgeInsets(top: 4, left: 0, bottom: 2, right: 0),
                marqueeTextInsets: UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0),
                maxStaticLines: 2,
                pointsPerSecond: 22,
                marqueeSpacing: 32,
                fadeWidth: 16,
                initialPause: 1.0,
                loopPause: 1.4
            )
        case .unitedStatesEn:
            return HeadlineStyle(
                font: roundedFont(size: 22, weight: .heavy),
                lineSpacing: 4,
                rubySizeFactor: 0.3,
                rubyLineReserve: 0,
                staticTextInsets: .zero,
                marqueeTextInsets: .zero,
                maxStaticLines: 2,
                pointsPerSecond: 26,
                marqueeSpacing: 28,
                fadeWidth: 16,
                initialPause: 0.9,
                loopPause: 1.2
            )
        }
    }

    nonisolated static func preferredHeight(
        for width: CGFloat,
        headline: String,
        edition: AppEdition,
        allowScroll: Bool
    ) -> CGFloat {
        let style = style(for: edition)
        let lineCount = lineCount(for: headline, width: width, edition: edition)

        if allowScroll && lineCount > style.maxStaticLines {
            return marqueeHeight(for: edition)
        }

        return staticHeight(for: edition, visibleLineCount: min(style.maxStaticLines, lineCount))
    }

    nonisolated static func shouldScroll(for width: CGFloat, headline: String, edition: AppEdition) -> Bool {
        let style = style(for: edition)
        return lineCount(for: headline, width: width, edition: edition) > style.maxStaticLines
    }

    fileprivate nonisolated static func marqueeHeight(for edition: AppEdition) -> CGFloat {
        let style = style(for: edition)
        return style.font.lineHeight + style.rubyLineReserve + style.marqueeTextInsets.top + style.marqueeTextInsets.bottom
    }

    fileprivate nonisolated static func staticHeight(for edition: AppEdition, visibleLineCount: Int) -> CGFloat {
        let style = style(for: edition)
        let lineCount = max(1, visibleLineCount)
        return style.staticTextInsets.top
            + style.staticTextInsets.bottom
            + CGFloat(lineCount) * (style.font.lineHeight + style.rubyLineReserve)
            + CGFloat(max(0, lineCount - 1)) * style.lineSpacing
    }

    private nonisolated static func lineCount(for headline: String, width: CGFloat, edition: AppEdition) -> Int {
        let rect = plainHeadline(headline, edition: edition).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let style = style(for: edition)
        let measuredHeight = max(rect.height, style.font.lineHeight)
        let lineUnit = max(1, style.font.lineHeight + style.lineSpacing)
        return max(1, Int(ceil((measuredHeight + style.lineSpacing) / lineUnit)))
    }

    private nonisolated static func plainHeadline(_ headline: String, edition: AppEdition) -> NSAttributedString {
        let style = style(for: edition)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = style.lineSpacing
        paragraphStyle.lineHeightMultiple = 1.0

        return NSAttributedString(
            string: headline,
            attributes: [
                .font: style.font,
                .paragraphStyle: paragraphStyle,
                .kern: edition == .taiwanZhHant ? 0.4 : 0
            ]
        )
    }

    private nonisolated static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        guard let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) else {
            return systemFont
        }

        return UIFont(descriptor: roundedDescriptor, size: size)
    }
}

enum HeadlineRubyFormatter {
    private nonisolated static var rubyKey: NSAttributedString.Key {
        NSAttributedString.Key(rawValue: kCTRubyAnnotationAttributeName as String)
    }

    nonisolated static func attributedHeadline(_ headline: String, edition: AppEdition) -> NSAttributedString {
        let style = HeadlineLayout.style(for: edition)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = style.lineSpacing
        paragraphStyle.lineHeightMultiple = 1.0

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle,
            .kern: edition == .taiwanZhHant ? 0.4 : 0
        ]

        let attributed = NSMutableAttributedString(string: headline, attributes: baseAttributes)
        guard edition.readingSupport.headlineAnnotationStyle == .zhuyin else {
            return attributed
        }

        annotateZhuyin(in: attributed, headline: headline, edition: edition)
        return attributed
    }

    private nonisolated static func annotateZhuyin(
        in attributed: NSMutableAttributedString,
        headline: String,
        edition: AppEdition
    ) {
        let headlineCF = headline as CFString
        let headlineNSString = headline as NSString
        let tokenizer = CFStringTokenizerCreate(
            nil,
            headlineCF,
            CFRange(location: 0, length: CFStringGetLength(headlineCF)),
            kCFStringTokenizerUnitWord,
            Locale(identifier: "zh_Hant_TW") as CFLocale
        )

        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while tokenType.rawValue != 0 {
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let nsRange = NSRange(location: tokenRange.location, length: tokenRange.length)
            let token = headlineNSString.substring(with: nsRange)

            if token.range(of: "\\p{Han}", options: .regularExpression) != nil {
                let bopomofoSyllables = mandarinLatinSyllables(for: token)
                    .map(ZhuyinPinyinConverter.bopomofo)
                    .filter { $0.isEmpty == false }

                if bopomofoSyllables.count == token.count {
                    for (index, ruby) in bopomofoSyllables.enumerated() {
                        let charRange = NSRange(location: nsRange.location + index, length: 1)
                        attributed.addAttribute(rubyKey, value: rubyAnnotation(for: ruby, edition: edition), range: charRange)
                    }
                } else if bopomofoSyllables.isEmpty == false {
                    attributed.addAttribute(
                        rubyKey,
                        value: rubyAnnotation(for: bopomofoSyllables.joined(separator: " "), edition: edition),
                        range: nsRange
                    )
                }
            }

            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
    }

    private nonisolated static func mandarinLatinSyllables(for token: String) -> [String] {
        let mutable = NSMutableString(string: token)
        guard CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false) else {
            return []
        }

        return (mutable as String)
            .replacingOccurrences(of: "'", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private nonisolated static func rubyAnnotation(for ruby: String, edition: AppEdition) -> CTRubyAnnotation {
        let style = HeadlineLayout.style(for: edition)
        let attributes: [CFString: Any] = [
            kCTRubyAnnotationSizeFactorAttributeName: style.rubySizeFactor,
            kCTRubyAnnotationScaleToFitAttributeName: true
        ]

        return CTRubyAnnotationCreateWithAttributes(
            .center,
            .auto,
            .before,
            ruby as CFString,
            attributes as CFDictionary
        )
    }
}

enum ZhuyinPinyinConverter {
    private nonisolated static var initials: [String: String] {
        [
            "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ",
            "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ",
            "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
            "j": "ㄐ", "q": "ㄑ", "x": "ㄒ",
            "zh": "ㄓ", "ch": "ㄔ", "sh": "ㄕ", "r": "ㄖ",
            "z": "ㄗ", "c": "ㄘ", "s": "ㄙ"
        ]
    }

    private nonisolated static var finals: [String: String] {
        [
            "": "",
            "a": "ㄚ",
            "o": "ㄛ",
            "e": "ㄜ",
            "ai": "ㄞ",
            "ei": "ㄟ",
            "ao": "ㄠ",
            "ou": "ㄡ",
            "an": "ㄢ",
            "en": "ㄣ",
            "ang": "ㄤ",
            "eng": "ㄥ",
            "er": "ㄦ",
            "i": "ㄧ",
            "ia": "ㄧㄚ",
            "io": "ㄧㄛ",
            "ie": "ㄧㄝ",
            "iao": "ㄧㄠ",
            "iou": "ㄧㄡ",
            "ian": "ㄧㄢ",
            "in": "ㄧㄣ",
            "iang": "ㄧㄤ",
            "ing": "ㄧㄥ",
            "iong": "ㄩㄥ",
            "u": "ㄨ",
            "ua": "ㄨㄚ",
            "uo": "ㄨㄛ",
            "uai": "ㄨㄞ",
            "uei": "ㄨㄟ",
            "uan": "ㄨㄢ",
            "uen": "ㄨㄣ",
            "uang": "ㄨㄤ",
            "ueng": "ㄨㄥ",
            "ong": "ㄨㄥ",
            "ü": "ㄩ",
            "üe": "ㄩㄝ",
            "üan": "ㄩㄢ",
            "ün": "ㄩㄣ"
        ]
    }

    private nonisolated static var diacritics: [Character: (String, Int)] {
        [
            "ā": ("a", 1), "á": ("a", 2), "ǎ": ("a", 3), "à": ("a", 4),
            "ē": ("e", 1), "é": ("e", 2), "ě": ("e", 3), "è": ("e", 4),
            "ī": ("i", 1), "í": ("i", 2), "ǐ": ("i", 3), "ì": ("i", 4),
            "ō": ("o", 1), "ó": ("o", 2), "ǒ": ("o", 3), "ò": ("o", 4),
            "ū": ("u", 1), "ú": ("u", 2), "ǔ": ("u", 3), "ù": ("u", 4),
            "ǖ": ("ü", 1), "ǘ": ("ü", 2), "ǚ": ("ü", 3), "ǜ": ("ü", 4),
            "ü": ("ü", 5), "ê": ("e", 5)
        ]
    }

    nonisolated static func bopomofo(_ pinyin: String) -> String {
        let normalized = normalize(pinyin)
        guard normalized.base.isEmpty == false else {
            return ""
        }

        if let shorthand = shorthandBopomofo(for: normalized.base, tone: normalized.tone) {
            return shorthand
        }

        let parsed = parseSyllable(normalized.base)
        let initial = initials[parsed.initial] ?? ""
        let final = finals[parsed.final] ?? ""
        let syllable = initial + final

        guard syllable.isEmpty == false else {
            return ""
        }

        return applyTone(normalized.tone, to: syllable)
    }

    private nonisolated static func shorthandBopomofo(for syllable: String, tone: Int) -> String? {
        let shorthands = [
            "zhi": "ㄓ",
            "chi": "ㄔ",
            "shi": "ㄕ",
            "ri": "ㄖ",
            "zi": "ㄗ",
            "ci": "ㄘ",
            "si": "ㄙ"
        ]

        guard let base = shorthands[syllable] else {
            return nil
        }

        return applyTone(tone, to: base)
    }

    private nonisolated static func parseSyllable(_ syllable: String) -> (initial: String, final: String) {
        if syllable.hasPrefix("y") {
            return ("", normalizeY(String(syllable.dropFirst())))
        }

        if syllable.hasPrefix("w") {
            return ("", normalizeW(String(syllable.dropFirst())))
        }

        for candidate in ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s"] {
            if syllable.hasPrefix(candidate) {
                var final = String(syllable.dropFirst(candidate.count))
                if ["j", "q", "x"].contains(candidate), final.hasPrefix("u") {
                    final.replaceSubrange(final.startIndex...final.startIndex, with: "ü")
                }

                switch final {
                case "iu":
                    final = "iou"
                case "ui":
                    final = "uei"
                case "un":
                    final = "uen"
                case "ue" where ["j", "q", "x"].contains(candidate):
                    final = "üe"
                default:
                    break
                }

                return (candidate, final)
            }
        }

        var final = syllable
        switch final {
        case "iu":
            final = "iou"
        case "ui":
            final = "uei"
        case "un":
            final = "uen"
        default:
            break
        }
        return ("", final)
    }

    private nonisolated static func normalizeY(_ rest: String) -> String {
        switch rest {
        case "", "i":
            return "i"
        case "a":
            return "ia"
        case "o":
            return "io"
        case "e":
            return "ie"
        case "ao":
            return "iao"
        case "ou":
            return "iou"
        case "an":
            return "ian"
        case "in":
            return "in"
        case "ang":
            return "iang"
        case "ing":
            return "ing"
        case "ong":
            return "iong"
        case "u":
            return "ü"
        case "ue":
            return "üe"
        case "uan":
            return "üan"
        case "un":
            return "ün"
        default:
            return rest
        }
    }

    private nonisolated static func normalizeW(_ rest: String) -> String {
        switch rest {
        case "", "u":
            return "u"
        case "a":
            return "ua"
        case "o":
            return "uo"
        case "ai":
            return "uai"
        case "ei":
            return "uei"
        case "an":
            return "uan"
        case "en":
            return "uen"
        case "ang":
            return "uang"
        case "eng":
            return "ueng"
        default:
            return "u" + rest
        }
    }

    private nonisolated static func normalize(_ syllable: String) -> (base: String, tone: Int) {
        var tone = 5
        var base = ""

        for character in syllable.lowercased() {
            if let mapped = diacritics[character] {
                base += mapped.0
                tone = mapped.1
                continue
            }

            if character.isNumber, let digit = Int(String(character)), (1...5).contains(digit) {
                tone = digit
                continue
            }

            if character == "v" {
                base += "ü"
                continue
            }

            if character == ":" || character == "'" {
                continue
            }

            base.append(character)
        }

        if tone == 5, syllable.rangeOfCharacter(from: CharacterSet(charactersIn: "āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ")) == nil {
            tone = 1
        }

        return (base, tone)
    }

    private nonisolated static func applyTone(_ tone: Int, to syllable: String) -> String {
        switch tone {
        case 2:
            return syllable + "ˊ"
        case 3:
            return syllable + "ˇ"
        case 4:
            return syllable + "ˋ"
        case 5:
            return "˙" + syllable
        default:
            return syllable
        }
    }
}
