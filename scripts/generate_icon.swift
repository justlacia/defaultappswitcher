import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: swift generate_icon.swift <output-icns-path>\n", stderr)
    exit(1)
}

let outputICNSPath = CommandLine.arguments[1]
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("das_icon_\(UUID().uuidString)", isDirectory: true)
let iconsetDir = tempDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
defer {
    try? FileManager.default.removeItem(at: tempDir)
}

func renderIcon(pixelSize: Int) -> Data? {
    let size = CGFloat(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    cg.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let inset = size * 0.08
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = rect.width * 0.225
    let squirclePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    cg.saveGState()
    squirclePath.addClip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(calibratedRed: 0.145, green: 0.388, blue: 0.922, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.310, green: 0.275, blue: 0.898, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    // Subtle top glow
    let glowColors = [
        NSColor.white.withAlphaComponent(0.18).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        cg.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: rect.midX, y: rect.maxY),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.maxY),
            endRadius: rect.width * 0.85,
            options: []
        )
    }

    // Inner highlight border
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.24).cgColor)
    cg.setLineWidth(max(1.0, size * 0.016))
    cg.addPath(squirclePath.cgPath)
    cg.strokePath()

    // Reliable macOS 14+ SF Symbol artwork: circular reset/switch emblem
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "arrow.counterclockwise.circle.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor.white.set()
        let symRect = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: symRect)
        symRect.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let drawRect = NSRect(
            x: (size - symbol.size.width) / 2.0,
            y: (size - symbol.size.height) / 2.0,
            width: symbol.size.width,
            height: symbol.size.height
        )
        tinted.draw(in: drawRect)
    }

    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in sizes {
    guard let png = renderIcon(pixelSize: item.px) else {
        fputs("Failed to render \(item.name)\n", stderr)
        exit(1)
    }
    try png.write(to: iconsetDir.appendingPathComponent(item.name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", outputICNSPath]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    fputs("iconutil failed with status \(iconutil.terminationStatus)\n", stderr)
    exit(iconutil.terminationStatus)
}
print("Generated icon at \(outputICNSPath)")
