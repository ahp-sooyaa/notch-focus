// Draws the NotchFocus app icon (coral tile, black notch, white timer ring) and
// writes Resources/AppIcon.icns. Run from the repo root: swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

/// Draws into a 1024×1024 design space with y pointing down.
func drawIcon(_ ctx: CGContext) {
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow (y-down space, so +y offsets downward on screen).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0xA0281E, 0.35))
    ctx.addPath(tile)
    ctx.setFillColor(color(0xE8443A))
    ctx.fillPath()
    ctx.restoreGState()

    // Coral gradient, lighter at the top.
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xFF7E70), color(0xE8443A)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    ctx.restoreGState()

    // Notch hanging from the top edge, with its camera dot.
    let notch = CGMutablePath()
    notch.move(to: CGPoint(x: 362, y: 100))
    notch.addLine(to: CGPoint(x: 662, y: 100))
    notch.addLine(to: CGPoint(x: 662, y: 150))
    notch.addArc(tangent1End: CGPoint(x: 662, y: 192), tangent2End: CGPoint(x: 620, y: 192), radius: 42)
    notch.addLine(to: CGPoint(x: 404, y: 192))
    notch.addArc(tangent1End: CGPoint(x: 362, y: 192), tangent2End: CGPoint(x: 362, y: 150), radius: 42)
    notch.closeSubpath()
    ctx.addPath(notch)
    ctx.setFillColor(color(0x000000))
    ctx.fillPath()
    ctx.setFillColor(color(0x1B2033))
    ctx.fillEllipse(in: CGRect(x: 501, y: 131, width: 22, height: 22))

    // Ring track and 75% progress arc, clockwise from 12 o'clock.
    let center = CGPoint(x: 512, y: 566)
    ctx.setLineWidth(56)
    ctx.setStrokeColor(color(0xFFFFFF, 0.28))
    ctx.strokeEllipse(in: CGRect(x: center.x - 226, y: center.y - 226, width: 452, height: 452))

    ctx.setLineCap(.round)
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.addArc(center: center, radius: 226, startAngle: -.pi / 2, endAngle: .pi, clockwise: false)
    ctx.strokePath()

    // Soft glow at the head of the arc.
    ctx.setFillColor(color(0xFFFFFF, 0.25))
    ctx.fillEllipse(in: CGRect(x: 286 - 58, y: 566 - 58, width: 116, height: 116))
}

func png(size: Int) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(size) / 1024
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)
    drawIcon(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

try fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote Resources/AppIcon.icns")
