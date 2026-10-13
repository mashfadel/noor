// Renders the Noor app icon: a neon point of light radiating on black.
// Usage: swift Tools/noor/make_icon.swift <out.png> [hex accent]
import AppKit

let out = CommandLine.arguments[1]
let hex = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "#CCFF00"
func rgb(_ h: String) -> (CGFloat, CGFloat, CGFloat) {
    let v = Int(h.dropFirst(), radix: 16)!
    return (CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255)
}
let (r, g, b) = rgb(hex)
let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func neon(_ a: CGFloat) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }

// Background: near-black with a faint vertical lift.
let bg = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 0.085, alpha: 1), CGColor(gray: 0.02, alpha: 1)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

let c = CGPoint(x: S / 2, y: S / 2)
// Soft halo.
let halo = CGGradient(colorsSpace: cs, colors: [neon(0.55), neon(0.12), neon(0)] as CFArray, locations: [0, 0.35, 1])!
ctx.drawRadialGradient(halo, startCenter: c, startRadius: 0, endCenter: c, endRadius: 360, options: [])

// Radiating rings, fading outward.
for (radius, alpha, width) in [(250.0, 0.55, 14.0), (345.0, 0.28, 9.0), (430.0, 0.12, 6.0)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.setStrokeColor(neon(alpha)); ctx.setLineWidth(width)
    ctx.strokeEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
}
// Solid core with a white-hot centre.
ctx.setFillColor(neon(1)); ctx.fillEllipse(in: CGRect(x: c.x - 120, y: c.y - 120, width: 240, height: 240))
let hot = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 1, alpha: 0.85), neon(0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(hot, startCenter: c, startRadius: 0, endCenter: c, endRadius: 95, options: [])

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
