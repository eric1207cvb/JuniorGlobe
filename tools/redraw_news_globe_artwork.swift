import AppKit
import Foundation

struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let panel: NSColor
    let panelGlow: NSColor
    let globeOcean: NSColor
    let globeLand: NSColor
    let globeGrid: NSColor
    let cardFill: NSColor
    let cardStroke: NSColor
    let cardInk: NSColor
    let cardAccentBlue: NSColor
    let cardAccentCoral: NSColor
    let cardAccentYellow: NSColor
    let orbit: NSColor
}

enum Variant {
    case icon
    case darkIcon
    case tintedIcon
    case launch
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconURL = root.appendingPathComponent("JuniorGlobe/Assets.xcassets/AppIcon.appiconset")
let launchArtworkURL = root.appendingPathComponent("JuniorGlobe/Assets.xcassets/LaunchSplashArtwork.imageset")
let launchBackgroundURL = root.appendingPathComponent("JuniorGlobe/Assets.xcassets/LaunchBackground.colorset/Contents.json")

let brightPalette = Palette(
    backgroundTop: NSColor(calibratedRed: 0.36, green: 0.84, blue: 0.98, alpha: 1),
    backgroundBottom: NSColor(calibratedRed: 1.00, green: 0.87, blue: 0.57, alpha: 1),
    panel: NSColor(calibratedRed: 0.88, green: 0.97, blue: 0.93, alpha: 0.60),
    panelGlow: NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.75, alpha: 0.70),
    globeOcean: NSColor(calibratedRed: 0.23, green: 0.75, blue: 0.92, alpha: 1),
    globeLand: NSColor(calibratedRed: 0.65, green: 0.86, blue: 0.51, alpha: 1),
    globeGrid: NSColor(calibratedRed: 0.77, green: 0.95, blue: 1.00, alpha: 0.55),
    cardFill: NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 0.97),
    cardStroke: NSColor(calibratedRed: 0.85, green: 0.93, blue: 0.98, alpha: 1),
    cardInk: NSColor(calibratedRed: 0.19, green: 0.43, blue: 0.63, alpha: 1),
    cardAccentBlue: NSColor(calibratedRed: 0.27, green: 0.67, blue: 0.97, alpha: 1),
    cardAccentCoral: NSColor(calibratedRed: 0.97, green: 0.46, blue: 0.39, alpha: 1),
    cardAccentYellow: NSColor(calibratedRed: 0.98, green: 0.79, blue: 0.27, alpha: 1),
    orbit: NSColor(calibratedRed: 1.00, green: 0.70, blue: 0.39, alpha: 1)
)

let darkPalette = Palette(
    backgroundTop: NSColor(calibratedRed: 0.18, green: 0.24, blue: 0.44, alpha: 1),
    backgroundBottom: NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.49, alpha: 1),
    panel: NSColor(calibratedRed: 0.45, green: 0.79, blue: 0.88, alpha: 0.16),
    panelGlow: NSColor(calibratedRed: 0.96, green: 0.83, blue: 0.42, alpha: 0.18),
    globeOcean: NSColor(calibratedRed: 0.28, green: 0.77, blue: 0.95, alpha: 1),
    globeLand: NSColor(calibratedRed: 0.71, green: 0.89, blue: 0.57, alpha: 1),
    globeGrid: NSColor(calibratedRed: 0.84, green: 0.96, blue: 1.00, alpha: 0.34),
    cardFill: NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.00, alpha: 0.96),
    cardStroke: NSColor(calibratedRed: 0.79, green: 0.90, blue: 0.98, alpha: 1),
    cardInk: NSColor(calibratedRed: 0.17, green: 0.39, blue: 0.56, alpha: 1),
    cardAccentBlue: NSColor(calibratedRed: 0.37, green: 0.77, blue: 0.99, alpha: 1),
    cardAccentCoral: NSColor(calibratedRed: 0.98, green: 0.54, blue: 0.47, alpha: 1),
    cardAccentYellow: NSColor(calibratedRed: 1.00, green: 0.83, blue: 0.38, alpha: 1),
    orbit: NSColor(calibratedRed: 1.00, green: 0.75, blue: 0.43, alpha: 1)
)

let launchPalette = Palette(
    backgroundTop: .clear,
    backgroundBottom: .clear,
    panel: NSColor(calibratedRed: 0.85, green: 0.96, blue: 0.92, alpha: 0.94),
    panelGlow: NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.79, alpha: 0.84),
    globeOcean: brightPalette.globeOcean,
    globeLand: brightPalette.globeLand,
    globeGrid: brightPalette.globeGrid,
    cardFill: brightPalette.cardFill,
    cardStroke: brightPalette.cardStroke,
    cardInk: brightPalette.cardInk,
    cardAccentBlue: brightPalette.cardAccentBlue,
    cardAccentCoral: brightPalette.cardAccentCoral,
    cardAccentYellow: brightPalette.cardAccentYellow,
    orbit: brightPalette.orbit
)

func savePNG(width: Int, height: Int, url: URL, draw: () -> Void) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "JuniorGlobe.Artwork", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap"])
    }

    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "JuniorGlobe.Artwork", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    try data.write(to: url)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawBackground(in rect: CGRect, palette: Palette, dark: Bool) {
    let gradient = NSGradient(colors: [palette.backgroundTop, palette.backgroundBottom])!
    gradient.draw(in: rect, angle: 305)

    let panelRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
    palette.panel.setFill()
    roundedRect(panelRect, radius: rect.width * 0.14).fill()

    palette.panelGlow.setFill()
    NSBezierPath(ovalIn: CGRect(
        x: rect.midX - rect.width * 0.22,
        y: rect.minY + rect.height * 0.08,
        width: rect.width * 0.52,
        height: rect.height * 0.34
    )).fill()

    let bubbleColor = NSColor.white.withAlphaComponent(dark ? 0.10 : 0.14)
    bubbleColor.setFill()
    for bubble in [
        CGRect(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.25, width: rect.width * 0.08, height: rect.width * 0.08),
        CGRect(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.18, width: rect.width * 0.06, height: rect.width * 0.06),
        CGRect(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.12, width: rect.width * 0.07, height: rect.width * 0.07)
    ] {
        NSBezierPath(ovalIn: bubble).fill()
    }
}

func drawOrbit(in rect: CGRect, palette: Palette, scale: CGFloat, offset: CGPoint) {
    palette.orbit.setStroke()
    let orbit = NSBezierPath()
    orbit.move(to: CGPoint(x: rect.midX - 330 * scale + offset.x, y: rect.midY - 92 * scale + offset.y))
    orbit.curve(
        to: CGPoint(x: rect.midX + 318 * scale + offset.x, y: rect.midY - 14 * scale + offset.y),
        controlPoint1: CGPoint(x: rect.midX - 214 * scale + offset.x, y: rect.midY - 210 * scale + offset.y),
        controlPoint2: CGPoint(x: rect.midX + 182 * scale + offset.x, y: rect.midY - 188 * scale + offset.y)
    )
    orbit.lineWidth = 24 * scale
    orbit.lineCapStyle = .round
    orbit.stroke()

    palette.orbit.withAlphaComponent(0.18).setStroke()
    let echo = NSBezierPath()
    echo.move(to: CGPoint(x: rect.midX - 250 * scale + offset.x, y: rect.midY + 182 * scale + offset.y))
    echo.curve(
        to: CGPoint(x: rect.midX + 244 * scale + offset.x, y: rect.midY + 112 * scale + offset.y),
        controlPoint1: CGPoint(x: rect.midX - 110 * scale + offset.x, y: rect.midY + 262 * scale + offset.y),
        controlPoint2: CGPoint(x: rect.midX + 100 * scale + offset.x, y: rect.midY + 242 * scale + offset.y)
    )
    echo.lineWidth = 14 * scale
    echo.lineCapStyle = .round
    echo.stroke()
}

func drawGlobe(in rect: CGRect, palette: Palette, scale: CGFloat, offset: CGPoint) {
    let globeRect = CGRect(
        x: rect.midX - 190 * scale + offset.x,
        y: rect.midY - 132 * scale + offset.y,
        width: 380 * scale,
        height: 380 * scale
    )

    palette.globeOcean.setFill()
    let globePath = NSBezierPath(ovalIn: globeRect)
    globePath.fill()

    let oceanGlow = NSGradient(colors: [
        palette.globeOcean.withAlphaComponent(0.05),
        NSColor.white.withAlphaComponent(0.16)
    ])!
    oceanGlow.draw(in: globePath, relativeCenterPosition: NSPoint(x: -0.25, y: 0.55))

    NSGraphicsContext.saveGraphicsState()
    globePath.addClip()

    palette.globeLand.setFill()
    let americas = NSBezierPath()
    americas.move(to: CGPoint(x: globeRect.minX + 78 * scale, y: globeRect.maxY - 62 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 118 * scale, y: globeRect.maxY - 96 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 96 * scale, y: globeRect.maxY - 30 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 118 * scale, y: globeRect.maxY - 58 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 124 * scale, y: globeRect.midY + 36 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 144 * scale, y: globeRect.maxY - 130 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 140 * scale, y: globeRect.midY + 84 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 100 * scale, y: globeRect.midY + 8 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 112 * scale, y: globeRect.midY + 22 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 108 * scale, y: globeRect.midY + 10 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 112 * scale, y: globeRect.minY + 42 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 84 * scale, y: globeRect.midY - 34 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 96 * scale, y: globeRect.minY + 70 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 146 * scale, y: globeRect.minY + 30 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 124 * scale, y: globeRect.minY + 22 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 136 * scale, y: globeRect.minY + 20 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 142 * scale, y: globeRect.minY + 106 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 162 * scale, y: globeRect.minY + 46 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 158 * scale, y: globeRect.minY + 76 * scale))
    americas.curve(to: CGPoint(x: globeRect.minX + 74 * scale, y: globeRect.maxY - 58 * scale),
                   controlPoint1: CGPoint(x: globeRect.minX + 114 * scale, y: globeRect.midY - 34 * scale),
                   controlPoint2: CGPoint(x: globeRect.minX + 62 * scale, y: globeRect.midY + 78 * scale))
    americas.close()
    americas.fill()

    let euroAfrica = NSBezierPath()
    euroAfrica.move(to: CGPoint(x: globeRect.midX + 40 * scale, y: globeRect.maxY - 74 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.maxX - 82 * scale, y: globeRect.maxY - 98 * scale),
                     controlPoint1: CGPoint(x: globeRect.midX + 68 * scale, y: globeRect.maxY - 38 * scale),
                     controlPoint2: CGPoint(x: globeRect.maxX - 88 * scale, y: globeRect.maxY - 56 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.maxX - 82 * scale, y: globeRect.midY + 38 * scale),
                     controlPoint1: CGPoint(x: globeRect.maxX - 56 * scale, y: globeRect.maxY - 138 * scale),
                     controlPoint2: CGPoint(x: globeRect.maxX - 44 * scale, y: globeRect.midY + 102 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.maxX - 116 * scale, y: globeRect.midY + 10 * scale),
                     controlPoint1: CGPoint(x: globeRect.maxX - 96 * scale, y: globeRect.midY + 20 * scale),
                     controlPoint2: CGPoint(x: globeRect.maxX - 110 * scale, y: globeRect.midY + 16 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.maxX - 128 * scale, y: globeRect.minY + 62 * scale),
                     controlPoint1: CGPoint(x: globeRect.maxX - 154 * scale, y: globeRect.midY - 54 * scale),
                     controlPoint2: CGPoint(x: globeRect.maxX - 146 * scale, y: globeRect.minY + 92 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.maxX - 82 * scale, y: globeRect.minY + 34 * scale),
                     controlPoint1: CGPoint(x: globeRect.maxX - 114 * scale, y: globeRect.minY + 28 * scale),
                     controlPoint2: CGPoint(x: globeRect.maxX - 94 * scale, y: globeRect.minY + 26 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.maxX - 48 * scale, y: globeRect.midY - 72 * scale),
                     controlPoint1: CGPoint(x: globeRect.maxX - 44 * scale, y: globeRect.minY + 62 * scale),
                     controlPoint2: CGPoint(x: globeRect.maxX - 24 * scale, y: globeRect.midY - 18 * scale))
    euroAfrica.curve(to: CGPoint(x: globeRect.midX + 36 * scale, y: globeRect.maxY - 78 * scale),
                     controlPoint1: CGPoint(x: globeRect.midX + 18 * scale, y: globeRect.midY + 22 * scale),
                     controlPoint2: CGPoint(x: globeRect.midX + 18 * scale, y: globeRect.maxY - 18 * scale))
    euroAfrica.close()
    euroAfrica.fill()

    let asia = NSBezierPath()
    asia.move(to: CGPoint(x: globeRect.maxX - 108 * scale, y: globeRect.maxY - 126 * scale))
    asia.curve(to: CGPoint(x: globeRect.maxX - 34 * scale, y: globeRect.maxY - 146 * scale),
               controlPoint1: CGPoint(x: globeRect.maxX - 84 * scale, y: globeRect.maxY - 102 * scale),
               controlPoint2: CGPoint(x: globeRect.maxX - 34 * scale, y: globeRect.maxY - 118 * scale))
    asia.curve(to: CGPoint(x: globeRect.maxX - 26 * scale, y: globeRect.midY + 98 * scale),
               controlPoint1: CGPoint(x: globeRect.maxX - 8 * scale, y: globeRect.maxY - 170 * scale),
               controlPoint2: CGPoint(x: globeRect.maxX + 10 * scale, y: globeRect.midY + 120 * scale))
    asia.curve(to: CGPoint(x: globeRect.maxX - 78 * scale, y: globeRect.midY + 82 * scale),
               controlPoint1: CGPoint(x: globeRect.maxX - 34 * scale, y: globeRect.midY + 76 * scale),
               controlPoint2: CGPoint(x: globeRect.maxX - 58 * scale, y: globeRect.midY + 76 * scale))
    asia.curve(to: CGPoint(x: globeRect.maxX - 112 * scale, y: globeRect.maxY - 126 * scale),
               controlPoint1: CGPoint(x: globeRect.maxX - 96 * scale, y: globeRect.midY + 118 * scale),
               controlPoint2: CGPoint(x: globeRect.maxX - 124 * scale, y: globeRect.midY + 144 * scale))
    asia.close()
    asia.fill()

    let australia = NSBezierPath(ovalIn: CGRect(
        x: globeRect.maxX - 106 * scale,
        y: globeRect.minY + 52 * scale,
        width: 54 * scale,
        height: 34 * scale
    ))
    australia.fill()

    palette.globeGrid.setStroke()
    for factor: CGFloat in [0.18, 0.34, 0.50, 0.66, 0.82] {
        let y = globeRect.minY + globeRect.height * factor
        let path = NSBezierPath()
        path.move(to: CGPoint(x: globeRect.minX + 10 * scale, y: y))
        path.curve(to: CGPoint(x: globeRect.maxX - 10 * scale, y: y),
                   controlPoint1: CGPoint(x: globeRect.minX + 102 * scale, y: y + 14 * scale),
                   controlPoint2: CGPoint(x: globeRect.maxX - 102 * scale, y: y - 14 * scale))
        path.lineWidth = 7 * scale
        path.stroke()
    }
    for xFactor: CGFloat in [0.18, 0.34, 0.50, 0.66, 0.82] {
        let x = globeRect.minX + globeRect.width * xFactor
        let path = NSBezierPath()
        path.move(to: CGPoint(x: x, y: globeRect.minY + 20 * scale))
        path.curve(to: CGPoint(x: x, y: globeRect.maxY - 20 * scale),
                   controlPoint1: CGPoint(x: x - 26 * scale, y: globeRect.midY - 112 * scale),
                   controlPoint2: CGPoint(x: x + 26 * scale, y: globeRect.midY + 112 * scale))
        path.lineWidth = 7 * scale
        path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
}

func drawCard(at center: CGPoint, size: CGSize, angle: CGFloat, palette: Palette, scale: CGFloat, lineCount: Int) {
    let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: angle * .pi / 180)
    context.translateBy(x: -rect.midX, y: -rect.midY)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    palette.cardFill.setFill()
    let cardPath = roundedRect(rect, radius: 34 * scale)
    cardPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    palette.cardStroke.setStroke()
    let outline = roundedRect(rect, radius: 34 * scale)
    outline.lineWidth = 6 * scale
    outline.stroke()

    let accentRect = CGRect(x: rect.minX, y: rect.maxY - 56 * scale, width: rect.width, height: 56 * scale)
    palette.cardAccentBlue.setFill()
    roundedRect(accentRect, radius: 34 * scale).fill()

    palette.cardInk.withAlphaComponent(0.24).setFill()
    NSBezierPath(ovalIn: CGRect(x: rect.minX + 22 * scale, y: rect.maxY - 40 * scale, width: 18 * scale, height: 18 * scale)).fill()

    palette.cardInk.withAlphaComponent(0.9).setStroke()
    let titleLine = NSBezierPath()
    titleLine.move(to: CGPoint(x: rect.minX + 54 * scale, y: rect.maxY - 30 * scale))
    titleLine.line(to: CGPoint(x: rect.maxX - 24 * scale, y: rect.maxY - 30 * scale))
    titleLine.lineWidth = 8 * scale
    titleLine.lineCapStyle = .round
    titleLine.stroke()

    for index in 0..<lineCount {
        let y = rect.maxY - (74 + CGFloat(index) * 26) * scale
        let widthInset = index == lineCount - 1 ? 36 : 18
        let line = NSBezierPath()
        line.move(to: CGPoint(x: rect.minX + 22 * scale, y: y))
        line.line(to: CGPoint(x: rect.maxX - CGFloat(widthInset) * scale, y: y))
        line.lineWidth = 6 * scale
        line.lineCapStyle = .round
        palette.cardInk.withAlphaComponent(0.28).setStroke()
        line.stroke()
    }

    context.restoreGState()
}

func drawMiniNewsCard(at center: CGPoint, size: CGSize, angle: CGFloat, palette: Palette, scale: CGFloat, accent: NSColor) {
    let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: angle * .pi / 180)
    context.translateBy(x: -rect.midX, y: -rect.midY)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 18 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -6 * scale)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.08)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    palette.cardFill.setFill()
    roundedRect(rect, radius: 24 * scale).fill()
    NSGraphicsContext.restoreGraphicsState()

    palette.cardStroke.setStroke()
    let border = roundedRect(rect, radius: 24 * scale)
    border.lineWidth = 4 * scale
    border.stroke()

    accent.setFill()
    roundedRect(CGRect(x: rect.minX + 12 * scale, y: rect.maxY - 28 * scale, width: rect.width * 0.56, height: 18 * scale), radius: 10 * scale).fill()

    for index in 0..<2 {
        let y = rect.maxY - (46 + CGFloat(index) * 16) * scale
        let line = NSBezierPath()
        line.move(to: CGPoint(x: rect.minX + 14 * scale, y: y))
        line.line(to: CGPoint(x: rect.maxX - 18 * scale, y: y))
        line.lineWidth = 5 * scale
        line.lineCapStyle = .round
        palette.cardInk.withAlphaComponent(0.24).setStroke()
        line.stroke()
    }

    context.restoreGState()
}

func drawEmblem(in rect: CGRect, palette: Palette, scale: CGFloat, monochrome: Bool = false) {
    if monochrome {
        let mono = NSColor(calibratedRed: 0.17, green: 0.55, blue: 0.75, alpha: 1)
        let panelRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.14)
        mono.withAlphaComponent(0.10).setFill()
        roundedRect(panelRect, radius: rect.width * 0.14).fill()
    }

    let offset = CGPoint(x: 0, y: 20 * scale)

    drawOrbit(in: rect, palette: monochrome ? Palette(
        backgroundTop: .clear, backgroundBottom: .clear, panel: .clear, panelGlow: .clear,
        globeOcean: .white, globeLand: .white, globeGrid: .white,
        cardFill: .white, cardStroke: .white, cardInk: .white,
        cardAccentBlue: .white, cardAccentCoral: .white, cardAccentYellow: .white,
        orbit: NSColor(calibratedRed: 0.17, green: 0.55, blue: 0.75, alpha: 1)
    ) : palette, scale: scale, offset: offset)

    if monochrome {
        let globeRect = CGRect(x: rect.midX - 200 * scale + offset.x, y: rect.midY - 150 * scale + offset.y, width: 400 * scale, height: 400 * scale)
        let mono = NSColor(calibratedRed: 0.17, green: 0.55, blue: 0.75, alpha: 1)
        mono.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: globeRect).fill()
        mono.withAlphaComponent(0.35).setStroke()
        for factor: CGFloat in [0.22, 0.40, 0.58, 0.76] {
            let y = globeRect.minY + globeRect.height * factor
            let path = NSBezierPath()
            path.move(to: CGPoint(x: globeRect.minX + 16 * scale, y: y))
            path.curve(to: CGPoint(x: globeRect.maxX - 16 * scale, y: y),
                       controlPoint1: CGPoint(x: globeRect.minX + 110 * scale, y: y + 12 * scale),
                       controlPoint2: CGPoint(x: globeRect.maxX - 110 * scale, y: y - 12 * scale))
            path.lineWidth = 8 * scale
            path.stroke()
        }
        for xFactor: CGFloat in [0.24, 0.42, 0.58, 0.76] {
            let x = globeRect.minX + globeRect.width * xFactor
            let path = NSBezierPath()
            path.move(to: CGPoint(x: x, y: globeRect.minY + 20 * scale))
            path.curve(to: CGPoint(x: x, y: globeRect.maxY - 20 * scale),
                       controlPoint1: CGPoint(x: x - 22 * scale, y: globeRect.midY - 110 * scale),
                       controlPoint2: CGPoint(x: x + 22 * scale, y: globeRect.midY + 110 * scale))
            path.lineWidth = 7 * scale
            path.stroke()
        }

        let monoCardFill = NSColor.white.withAlphaComponent(0.94)
        let monoPalette = Palette(
            backgroundTop: .clear, backgroundBottom: .clear, panel: .clear, panelGlow: .clear,
            globeOcean: mono, globeLand: mono, globeGrid: mono.withAlphaComponent(0.35),
            cardFill: monoCardFill, cardStroke: mono.withAlphaComponent(0.16), cardInk: mono,
            cardAccentBlue: mono, cardAccentCoral: mono, cardAccentYellow: mono, orbit: mono
        )
        drawMiniNewsCard(at: CGPoint(x: rect.midX - 250 * scale, y: rect.midY + 8 * scale), size: CGSize(width: 112 * scale, height: 84 * scale), angle: -6, palette: monoPalette, scale: scale, accent: mono)
        drawMiniNewsCard(at: CGPoint(x: rect.midX + 160 * scale, y: rect.midY + 112 * scale), size: CGSize(width: 104 * scale, height: 78 * scale), angle: 5, palette: monoPalette, scale: scale, accent: mono)
        drawMiniNewsCard(at: CGPoint(x: rect.midX + 262 * scale, y: rect.midY - 8 * scale), size: CGSize(width: 112 * scale, height: 84 * scale), angle: -4, palette: monoPalette, scale: scale, accent: mono)
        drawCard(at: CGPoint(x: rect.midX + 172 * scale, y: rect.midY - 108 * scale), size: CGSize(width: 220 * scale, height: 168 * scale), angle: -14, palette: monoPalette, scale: scale, lineCount: 3)
    } else {
        drawGlobe(in: rect, palette: palette, scale: scale, offset: offset)
        drawMiniNewsCard(at: CGPoint(x: rect.midX - 250 * scale, y: rect.midY + 8 * scale), size: CGSize(width: 112 * scale, height: 84 * scale), angle: -6, palette: palette, scale: scale, accent: palette.cardAccentBlue)
        drawMiniNewsCard(at: CGPoint(x: rect.midX + 160 * scale, y: rect.midY + 112 * scale), size: CGSize(width: 104 * scale, height: 78 * scale), angle: 5, palette: palette, scale: scale, accent: palette.cardAccentYellow)
        drawMiniNewsCard(at: CGPoint(x: rect.midX + 262 * scale, y: rect.midY - 8 * scale), size: CGSize(width: 112 * scale, height: 84 * scale), angle: -4, palette: palette, scale: scale, accent: palette.cardAccentCoral)
        drawCard(at: CGPoint(x: rect.midX + 172 * scale, y: rect.midY - 108 * scale), size: CGSize(width: 220 * scale, height: 168 * scale), angle: -14, palette: palette, scale: scale, lineCount: 3)
    }
}

func renderAppIconVariant(size: Int, variant: Variant, outputURL: URL) throws {
    try savePNG(width: size, height: size, url: outputURL) {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        switch variant {
        case .icon:
            drawBackground(in: rect, palette: brightPalette, dark: false)
            drawEmblem(in: rect, palette: brightPalette, scale: CGFloat(size) / 1024)
        case .darkIcon:
            drawBackground(in: rect, palette: darkPalette, dark: true)
            drawEmblem(in: rect, palette: darkPalette, scale: CGFloat(size) / 1024)
        case .tintedIcon:
            NSColor.clear.setFill()
            rect.fill()
            drawEmblem(in: rect, palette: brightPalette, scale: CGFloat(size) / 1024 * 0.94, monochrome: true)
        case .launch:
            break
        }
    }
}

func renderLaunchArtwork(size: Int, outputURL: URL) throws {
    try savePNG(width: size, height: size, url: outputURL) {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        NSColor.clear.setFill()
        rect.fill()

        let badgeRect = CGRect(
            x: rect.midX - rect.width * 0.37,
            y: rect.midY - rect.width * 0.37,
            width: rect.width * 0.74,
            height: rect.width * 0.74
        )
        let badge = NSBezierPath(ovalIn: badgeRect)
        let badgeGradient = NSGradient(colors: [launchPalette.panel, launchPalette.panelGlow])!
        badgeGradient.draw(in: badge, angle: 315)

        drawEmblem(in: rect, palette: launchPalette, scale: CGFloat(size) / 1024 * 0.92)
    }
}

func writeLaunchBackgroundColor() throws {
    let json = """
    {
      "colors" : [
        {
          "color" : {
            "color-space" : "srgb",
            "components" : {
              "alpha" : "1.000",
              "blue" : "0.941",
              "green" : "0.984",
              "red" : "0.973"
            }
          },
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try json.write(to: launchBackgroundURL, atomically: true, encoding: .utf8)
}

do {
    try renderAppIconVariant(size: 1024, variant: .icon, outputURL: appIconURL.appendingPathComponent("app-icon-1024.png"))
    try renderAppIconVariant(size: 1024, variant: .darkIcon, outputURL: appIconURL.appendingPathComponent("app-icon-1024-dark.png"))
    try renderAppIconVariant(size: 1024, variant: .tintedIcon, outputURL: appIconURL.appendingPathComponent("app-icon-1024-tinted.png"))
    try renderLaunchArtwork(size: 320, outputURL: launchArtworkURL.appendingPathComponent("launch-artwork.png"))
    try renderLaunchArtwork(size: 640, outputURL: launchArtworkURL.appendingPathComponent("launch-artwork@2x.png"))
    try renderLaunchArtwork(size: 960, outputURL: launchArtworkURL.appendingPathComponent("launch-artwork@3x.png"))
    try writeLaunchBackgroundColor()
    print("Redrew JuniorGlobe icon and launch artwork.")
} catch {
    fputs("Failed to redraw artwork: \\(error)\\n", stderr)
    exit(1)
}
