#!/usr/bin/env swift
// Renders the Blink app icon and writes every size into AppIcon.appiconset.
// Usage: swift apps/macos/scripts/generate-icon.swift

import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func withShadow(_ ctx: CGContext, color shadowColor: NSColor, blur: CGFloat, offsetY: CGFloat, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: offsetY), blur: blur, color: shadowColor.cgColor)
    draw()
    ctx.restoreGState()
}

func rotated(_ ctx: CGContext, around center: CGPoint, degrees: CGFloat, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.translateBy(x: -center.x, y: -center.y)
    draw()
    ctx.restoreGState()
}

func renderIcon() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Apple's macOS icon grid: 824pt body centered on a 1024pt canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    withShadow(ctx, color: color(0x000000, 0.35), blur: 24, offsetY: -12) {
        color(0x1E1B4B).setFill()
        squircle.fill()
    }

    ctx.saveGState()
    squircle.addClip()
    NSGradient(colors: [color(0x7C3AED), color(0x4338CA), color(0x1E1B4B)])!
        .draw(in: body, angle: -60)
    NSGradient(colors: [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)])!
        .draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)

    let cardRect = CGRect(x: 262, y: 230, width: 500, height: 560)
    let cardCenter = CGPoint(x: cardRect.midX, y: cardRect.midY)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 70, yRadius: 70)

    rotated(ctx, around: cardCenter, degrees: 9) {
        color(0xFFFFFF, 0.28).setFill()
        cardPath.fill()
    }

    rotated(ctx, around: cardCenter, degrees: -4) {
        withShadow(ctx, color: color(0x0B0A2A, 0.45), blur: 50, offsetY: -24) {
            color(0xFFFFFF, 0.97).setFill()
            cardPath.fill()
        }

        let lineHeight: CGFloat = 38
        let left = cardRect.minX + 70
        color(0xC7CBE0).setFill()
        for (index, width) in [CGFloat(330), 270].enumerated() {
            let y = cardRect.maxY - 120 - CGFloat(index) * 92
            NSBezierPath(roundedRect: CGRect(x: left, y: y, width: width, height: lineHeight),
                         xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
        }
        let lastY = cardRect.maxY - 120 - 2 * 92
        NSBezierPath(roundedRect: CGRect(x: left, y: lastY, width: 150, height: lineHeight),
                     xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()

        let caret = CGRect(x: left + 180, y: lastY - 34, width: 30, height: 106)
        withShadow(ctx, color: color(0xF59E0B, 0.9), blur: 46, offsetY: 0) {
            color(0xF59E0B).setFill()
            NSBezierPath(roundedRect: caret, xRadius: 15, yRadius: 15).fill()
        }
    }
    ctx.restoreGState()

    NSColor(white: 1, alpha: 0.12).setStroke()
    squircle.lineWidth = 3
    squircle.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func resized(_ source: NSBitmapImageRep, to pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    source.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let macosDir = scriptDir.deletingLastPathComponent()
let iconset = macosDir.appendingPathComponent("Blink/Resources/Assets.xcassets/AppIcon.appiconset")
let repoAssets = macosDir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("assets")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: repoAssets, withIntermediateDirectories: true)

let master = renderIcon()
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try resized(master, to: points * scale).write(to: iconset.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconset.appendingPathComponent("Contents.json"))
try resized(master, to: 512).write(to: repoAssets.appendingPathComponent("icon.png"))
print("Wrote icons to \(iconset.path)")
