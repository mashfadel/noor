// Renders the Noor app icon. Usage: swift Tools/noor/make_icon.swift <out.png> [orb|heart] [size]
//   orb   — a living sphere of light with a neon aurora inside (the default)
//   heart — a luminous heart made of the same aurora
import AppKit

let args = CommandLine.arguments
let out = args[1]
let style = args.count > 2 ? args[2] : "orb"
let S = CGFloat(args.count > 3 ? Double(args[3])! : 1024)
let k = S / 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                         CGFloat(hex & 0xFF) / 255, a])!
}
func radial(_ center: CGPoint, _ r: CGFloat, _ hex: UInt32, _ a: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: [c(hex, a), c(hex, a * 0.45), c(hex, 0)] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
}
let green: UInt32 = 0x3DFF8F, aqua: UInt32 = 0x1AF5D0, blue: UInt32 = 0x2E7BFF, pink: UInt32 = 0xFF3EA5, violet: UInt32 = 0x8A4BFF

// Black canvas with a faint lift.
let bg = CGGradient(colorsSpace: cs, colors: [c(0x101010), c(0x000000)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

let C = CGPoint(x: S / 2, y: S / 2)

/// The shape the aurora lives in.
func shapePath() -> CGPath {
    if style == "heart" {
        // A plump, soft heart (two lobes + point), centred.
        let p = CGMutablePath()
        let w: CGFloat = 640 * k, h: CGFloat = 580 * k
        let top = C.y + h * 0.36, bottom = C.y - h * 0.56
        p.move(to: CGPoint(x: C.x, y: bottom))
        p.addCurve(to: CGPoint(x: C.x - w / 2, y: top - h * 0.08),
                   control1: CGPoint(x: C.x - w * 0.14, y: bottom + h * 0.20),
                   control2: CGPoint(x: C.x - w / 2, y: top - h * 0.42))
        p.addCurve(to: CGPoint(x: C.x, y: top - h * 0.10),
                   control1: CGPoint(x: C.x - w / 2, y: top + h * 0.30),
                   control2: CGPoint(x: C.x - w * 0.06, y: top + h * 0.26))
        p.addCurve(to: CGPoint(x: C.x + w / 2, y: top - h * 0.08),
                   control1: CGPoint(x: C.x + w * 0.06, y: top + h * 0.26),
                   control2: CGPoint(x: C.x + w / 2, y: top + h * 0.30))
        p.addCurve(to: CGPoint(x: C.x, y: bottom),
                   control1: CGPoint(x: C.x + w / 2, y: top - h * 0.42),
                   control2: CGPoint(x: C.x + w * 0.14, y: bottom + h * 0.20))
        p.closeSubpath()
        return p
    }
    let r: CGFloat = 300 * k
    return CGPath(ellipseIn: CGRect(x: C.x - r, y: C.y - r, width: r * 2, height: r * 2), transform: nil)
}
let shape = shapePath()

// 1) Outer halo — light spilling into the dark.
ctx.saveGState()
ctx.setBlendMode(.screen)
radial(CGPoint(x: C.x - 110 * k, y: C.y + 80 * k), 560 * k, green, 0.30)
radial(CGPoint(x: C.x + 140 * k, y: C.y - 40 * k), 540 * k, blue, 0.30)
radial(CGPoint(x: C.x - 60 * k, y: C.y - 160 * k), 520 * k, pink, 0.28)
ctx.restoreGState()

// 2) The aurora, clipped to the shape.
ctx.saveGState()
ctx.addPath(shape); ctx.clip()
ctx.setFillColor(c(0x05060A)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
ctx.setBlendMode(.screen)
radial(CGPoint(x: C.x - 170 * k, y: C.y + 150 * k), 360 * k, green, 1.0)
radial(CGPoint(x: C.x + 20 * k, y: C.y + 230 * k), 260 * k, aqua, 0.75)
radial(CGPoint(x: C.x + 210 * k, y: C.y - 30 * k), 340 * k, blue, 1.0)
radial(CGPoint(x: C.x - 110 * k, y: C.y - 210 * k), 330 * k, pink, 1.0)
radial(CGPoint(x: C.x + 150 * k, y: C.y - 250 * k), 240 * k, violet, 0.85)
// Inner light: aqua where the colours meet, with a small hot core.
radial(CGPoint(x: C.x + 10 * k, y: C.y + 20 * k), 230 * k, aqua, 0.8)
radial(CGPoint(x: C.x - 10 * k, y: C.y + 30 * k), 120 * k, 0xFFFFFF, 0.35)
ctx.setBlendMode(.normal)
// Depth: darken toward the lower rim so it reads as a lit volume, not a flat blob.
let shade = CGGradient(colorsSpace: cs, colors: [c(0x000000, 0), c(0x000000, 0.55)] as CFArray, locations: [0.5, 1])!
ctx.drawRadialGradient(shade, startCenter: CGPoint(x: C.x - 60 * k, y: C.y + 80 * k), startRadius: 0,
                       endCenter: C, endRadius: 360 * k, options: [])
// Specular glint.
let glint = CGGradient(colorsSpace: cs, colors: [c(0xFFFFFF, 0.7), c(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
let gp = CGPoint(x: C.x - 130 * k, y: C.y + 180 * k)
ctx.drawRadialGradient(glint, startCenter: gp, startRadius: 0, endCenter: gp, endRadius: 64 * k, options: [])
ctx.restoreGState()

// 3) Rim light.
ctx.saveGState()
ctx.addPath(shape)
ctx.setLineWidth(3 * k)
ctx.setStrokeColor(c(0xFFFFFF, 0.12))
ctx.strokePath()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
