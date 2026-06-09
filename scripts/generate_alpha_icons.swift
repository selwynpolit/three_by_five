#!/usr/bin/env swift
// Generates AppIcon-Alpha asset set by compositing an orange "A" badge
// over each size of the existing AppIcon.
// Run from the project root: swift scripts/generate_alpha_icons.swift
import AppKit

let _ = NSApplication.shared

let root = FileManager.default.currentDirectoryPath
let src  = "\(root)/macos/Runner/Assets.xcassets/AppIcon.appiconset"
let dst  = "\(root)/macos/Runner/Assets.xcassets/AppIcon-Alpha.appiconset"

try! FileManager.default.createDirectory(atPath: dst, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    let inName  = "app_icon_\(size).png"
    let outName = "app_icon_alpha_\(size).png"

    guard let srcData = FileManager.default.contents(atPath: "\(src)/\(inName)"),
          let srcRep  = NSBitmapImageRep(data: srcData) else {
        print("⚠️  Cannot load \(inName), skipping")
        continue
    }

    guard let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { continue }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)

    let sz = CGFloat(size)

    // Draw source icon
    srcRep.draw(in: NSRect(x: 0, y: 0, width: sz, height: sz))

    // Orange badge — top-right corner (AppKit y=0 is bottom, so top = sz - h)
    let diam   = sz * 0.54
    let pad    = sz * 0.03
    let bx     = sz - diam - pad
    let by     = sz - diam - pad          // top in AppKit coords
    let bRect  = NSRect(x: bx, y: by, width: diam, height: diam)

    NSColor(red: 0.94, green: 0.42, blue: 0.0, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: bRect).fill()

    // White "A" centred in badge (skip for tiny icons — text won't be legible)
    if size >= 32 {
        let fontSize = diam * 0.65
        let font  = NSFont.boldSystemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let str   = NSAttributedString(string: "A", attributes: attrs)
        let sSize = str.size()
        str.draw(at: CGPoint(
            x: bx + (diam - sSize.width)  / 2,
            y: by + (diam - sSize.height) / 2
        ))
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bmp.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
        print("⚠️  Cannot encode \(size)px, skipping")
        continue
    }
    try! png.write(to: URL(fileURLWithPath: "\(dst)/\(outName)"))
    print("✓  \(size)px → \(outName)")
}

// Contents.json — same slot/scale mapping as AppIcon, different filenames
let contents = """
{
  "images" : [
    { "size" : "16x16",   "idiom" : "mac", "filename" : "app_icon_alpha_16.png",   "scale" : "1x" },
    { "size" : "16x16",   "idiom" : "mac", "filename" : "app_icon_alpha_32.png",   "scale" : "2x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "app_icon_alpha_32.png",   "scale" : "1x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "app_icon_alpha_64.png",   "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "app_icon_alpha_128.png",  "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "app_icon_alpha_256.png",  "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "app_icon_alpha_256.png",  "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "app_icon_alpha_512.png",  "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "app_icon_alpha_512.png",  "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "app_icon_alpha_1024.png", "scale" : "2x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
"""
try! contents.write(toFile: "\(dst)/Contents.json", atomically: true, encoding: .utf8)
print("✓  Contents.json")
print("Done — AppIcon-Alpha generated in \(dst)")
