#!/usr/bin/env swift
// Renders AppIcon.iconset (10 sizes) then iconutil packs AppIcon.icns.
// Flat blue roundrect, white "20". Rerun to tweak, commit the .icns.
import AppKit
import Foundation

let dir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let iconset = dir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                 xRadius: size * 0.225, yRadius: size * 0.225).fill()
    let text = "20" as NSString
    let font = NSFont.boldSystemFont(ofSize: size * 0.52)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - size * 0.02),
              withAttributes: attrs)
    image.unlockFocus()
    return image
}

let specs: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for spec in specs {
    let image = draw(size: spec.pixels)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("icon render failed at \(spec.pixels)\n", stderr)
        exit(1)
    }
    try png.write(to: iconset.appendingPathComponent("\(spec.name).png"))
}
print("wrote \(iconset.path)")
