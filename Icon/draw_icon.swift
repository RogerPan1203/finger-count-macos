import AppKit
import Foundation

private let width = 1024
private let height = 1024
private let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

guard let bitmap = NSBitmapImageRep(
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
), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to make icon bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 76, y: 88, width: 872, height: 872),
                        xRadius: 214, yRadius: 214)

// Deep forest surface with enough edge contrast at small Finder sizes.
let tileShadow = NSShadow()
tileShadow.shadowColor = color(2, 20, 17, 0.31)
tileShadow.shadowBlurRadius = 36
tileShadow.shadowOffset = NSSize(width: 0, height: -19)
NSGraphicsContext.saveGraphicsState()
tileShadow.set()
color(8, 42, 36).setFill()
tile.fill()
NSGraphicsContext.restoreGraphicsState()

let background = NSGradient(starting: color(22, 92, 75), ending: color(5, 33, 30))!
background.draw(in: tile, angle: -48)

NSGraphicsContext.saveGraphicsState()
tile.addClip()

let glow = NSGradient(starting: color(93, 240, 187, 0.22),
                      ending: color(93, 240, 187, 0.00))!
glow.draw(in: NSBezierPath(ovalIn: NSRect(x: -62, y: 415, width: 995, height: 995)),
          relativeCenterPosition: NSPoint(x: -0.16, y: 0.20))

// Quiet concentric scan rings give the mark depth without hurting legibility.
for inset in [CGFloat(98), 151] {
    let ring = NSBezierPath(ovalIn: NSRect(x: inset, y: inset,
                                         width: 1024 - inset * 2,
                                         height: 1024 - inset * 2))
    ring.lineWidth = 2
    color(191, 255, 227, inset == 98 ? 0.075 : 0.04).setStroke()
    ring.stroke()
}
NSGraphicsContext.restoreGraphicsState()

tile.lineWidth = 3
color(177, 255, 223, 0.15).setStroke()
tile.stroke()

// SF Symbols supplies a clean, optically balanced raised-hand silhouette.
let mint = color(164, 252, 204)
guard let sourceHand = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil),
      let hand = sourceHand.withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 580, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [mint]))
      ) else {
    fatalError("The hand.raised.fill system symbol is unavailable")
}

let handRect = NSRect(x: 207, y: 195, width: 610, height: 650)
let handShadow = NSShadow()
handShadow.shadowColor = color(0, 19, 15, 0.39)
handShadow.shadowBlurRadius = 24
handShadow.shadowOffset = NSSize(width: 0, height: -14)
NSGraphicsContext.saveGraphicsState()
handShadow.set()
hand.draw(in: handRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

// Number chip overlaps the palm just enough to read as a live-count label.
let badgeRect = NSRect(x: 660, y: 145, width: 224, height: 224)
let badge = NSBezierPath(ovalIn: badgeRect)
let badgeShadow = NSShadow()
badgeShadow.shadowColor = color(0, 20, 15, 0.45)
badgeShadow.shadowBlurRadius = 25
badgeShadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState()
badgeShadow.set()
color(218, 255, 124).setFill()
badge.fill()
NSGraphicsContext.restoreGraphicsState()

badge.lineWidth = 5
color(250, 255, 210, 0.58).setStroke()
badge.stroke()

let numeral = "5" as NSString
let textStyle: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 147, weight: .heavy),
    .foregroundColor: color(17, 61, 45)
]
let textSize = numeral.size(withAttributes: textStyle)
numeral.draw(at: NSPoint(x: badgeRect.midX - textSize.width / 2,
                         y: badgeRect.midY - textSize.height / 2 + 2),
             withAttributes: textStyle)

graphics.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try data.write(to: URL(fileURLWithPath: output))
