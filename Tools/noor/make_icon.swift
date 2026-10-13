// Renders the Noor app icon: light rising over a horizon — three concentric arcs for
// Sleep (violet→pink), Recovery (green) and Strain (blue→cyan) around a white-hot point of light.
// Usage: swift Tools/noor/make_icon.swift <out.png> [size] [--transparent]
import AppKit

let args = CommandLine.arguments
let out = args[1]
let S = CGFloat(args.count > 2 && Double(args[2]) != nil ? Double(args[2])! : 1024)
let transparent = args.contains("--transparent")
let k = S / 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: (transparent ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                         CGFloat(hex & 0xFF) / 255, a])!
}

if !transparent {
    let bg = CGGradient(colorsSpace: cs, colors: [c(0x161616), c(0x000000)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: S * 0.3), options: [.drawsAfterEndLocation])
}

// Horizon a little below centre (CG is y-up).
let center = CGPoint(x: S / 2, y: S * 0.36)
let w: CGFloat = 54 * k
// Each arc rises from the left horizon and fills to its own length, like three dials mid-fill.
let arcs: [(radius: CGFloat, fill: CGFloat, colors: [UInt32], glow: UInt32)] = [
    (352 * k, 1.00, [0xA24BFF, 0xFF3EA5], 0xFF3EA5),   // Sleep
    (262 * k, 0.78, [0x00C46A, 0x3DFF8F], 0x3DFF8F),   // Recovery
    (172 * k, 0.56, [0x2E6BFF, 0x33E1FF], 0x33E1FF),   // Strain
]

for arc in arcs {
    let path = CGMutablePath()
    path.addArc(center: center, radius: arc.radius, startAngle: .pi, endAngle: .pi * (1 - arc.fill), clockwise: true)
    // Bloom
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 46 * k, color: c(arc.glow, 0.85))
    ctx.addPath(path); ctx.setLineWidth(w); ctx.setLineCap(.round); ctx.setStrokeColor(c(arc.glow, 0.5)); ctx.strokePath()
    ctx.restoreGState()
    // Body: gradient across the arc, left → right.
    ctx.saveGState()
    ctx.addPath(path.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 1)); ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: arc.colors.map { c($0) } as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: CGPoint(x: center.x - arc.radius, y: center.y),
                           end: CGPoint(x: center.x + arc.radius, y: center.y),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let sheen = CGGradient(colorsSpace: cs, colors: [c(0xFFFFFF, 0.28), c(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: center.y + arc.radius + w / 2),
                           end: CGPoint(x: 0, y: center.y + arc.radius - w / 2), options: [.drawsBeforeStartLocation])
    ctx.restoreGState()
}

// The point of light on the horizon.
let halo = CGGradient(colorsSpace: cs, colors: [c(0xFFFFFF, 0.9), c(0xBFFFF2, 0.35), c(0x1AF5D0, 0)] as CFArray,
                      locations: [0, 0.35, 1])!
ctx.drawRadialGradient(halo, startCenter: center, startRadius: 0, endCenter: center, endRadius: 120 * k, options: [])
ctx.setFillColor(c(0xFFFFFF)); ctx.fillEllipse(in: CGRect(x: center.x - 34 * k, y: center.y - 34 * k, width: 68 * k, height: 68 * k))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
