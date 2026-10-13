// Renders the Noor app icon: the "oo" of noor as two interlocking neon rings on black.
// Usage: swift Tools/noor/make_icon.swift <out.png> [size]
import AppKit

let out = CommandLine.arguments[1]
let S = CGFloat(CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 1024)
let k = S / 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                         CGFloat(hex & 0xFF) / 255, a])!
}
let green: UInt32 = 0x3DFF8F, aqua: UInt32 = 0x1AF5D0, blue: UInt32 = 0x2E8BFF, pink: UInt32 = 0xFF3EA5, violet: UInt32 = 0xA24BFF

// Background: black with a faint lift at the top.
let bg = CGGradient(colorsSpace: cs, colors: [c(0x141414), c(0x000000)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: S * 0.35), options: [.drawsAfterEndLocation])

let r: CGFloat = 228 * k, w: CGFloat = 84 * k, dx: CGFloat = 146 * k
let left = CGPoint(x: S / 2 - dx, y: S / 2), right = CGPoint(x: S / 2 + dx, y: S / 2)

/// Strokes one ring filled with a gradient, with a neon bloom underneath.
func ring(_ center: CGPoint, _ colors: [UInt32], clipOut: CGRect? = nil, glow: UInt32, bloom: Bool = true) {
    let path = CGPath(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2), transform: nil)
    // Bloom: blurred stroke beneath.
    if bloom {
    ctx.saveGState()
    if let clipOut { ctx.addRect(CGRect(x: 0, y: 0, width: S, height: S)); ctx.addRect(clipOut); ctx.clip(using: .evenOdd) }
    ctx.setShadow(offset: .zero, blur: 70 * k, color: c(glow, 0.9))
    ctx.addPath(path); ctx.setLineWidth(w); ctx.setStrokeColor(c(glow, 0.55)); ctx.strokePath()
    ctx.restoreGState()
    }
    // Body: gradient clipped to the stroke.
    ctx.saveGState()
    if let clipOut { ctx.addRect(CGRect(x: 0, y: 0, width: S, height: S)); ctx.addRect(clipOut); ctx.clip(using: .evenOdd) }
    ctx.addPath(path.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 1)); ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: colors.map { c($0) } as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: CGPoint(x: center.x - r, y: center.y + r), end: CGPoint(x: center.x + r, y: center.y - r), options: [])
    // Specular sheen along the top of the tube.
    let sheen = CGGradient(colorsSpace: cs, colors: [c(0xFFFFFF, 0.35), c(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: center.x, y: center.y + r + w / 2), end: CGPoint(x: center.x, y: center.y), options: [])
    ctx.restoreGState()
}

// Interlock: draw the pink ring, then the green→blue ring, then re-draw the pink ring only where it
// should pass OVER (the lower crossing), so the two rings read as linked rather than stacked.
ring(right, [violet, pink], glow: pink)
ring(left, [green, aqua, blue], glow: aqua)
// Lower crossing: the pink ring passes over the green one. Body only (no bloom) and a round clip, so
// the re-draw leaves no seam.
let dy = (r * r - dx * dx).squareRoot()
let crossing = CGRect(x: S / 2 - w, y: S / 2 - dy - w, width: w * 2, height: w * 2)
ctx.saveGState(); ctx.addEllipse(in: crossing); ctx.clip()
ring(right, [violet, pink], glow: pink, bloom: false)
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
