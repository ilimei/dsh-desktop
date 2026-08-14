import AppKit

let args = CommandLine.arguments
guard args.count == 3,
      let maskImage = NSImage(contentsOfFile: args[1])
else { fatalError("usage: IconGenerator mask.png output.png") }

let size = 1024
guard let maskBitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let maskContext = NSGraphicsContext(bitmapImageRep: maskBitmap) else { fatalError("cannot create mask bitmap") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = maskContext
maskContext.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
maskImage.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
guard let maskCG = maskBitmap.cgImage else { fatalError("cannot render mask") }

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("cannot create bitmap") }

NSGraphicsContext.saveGraphicsState()
guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("cannot create context") }
NSGraphicsContext.current = graphics
let ctx = graphics.cgContext
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

let shellRect = CGRect(x: 58, y: 58, width: 908, height: 908)
let shell = CGPath(roundedRect: shellRect, cornerWidth: 214, cornerHeight: 214, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 32, color: NSColor.black.withAlphaComponent(0.48).cgColor)
ctx.addPath(shell)
ctx.clip()
let shellGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedWhite: 0.22, alpha: 1).cgColor,
        NSColor(calibratedWhite: 0.085, alpha: 1).cgColor,
        NSColor(calibratedWhite: 0.025, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 0.52, 1]
)!
ctx.drawLinearGradient(shellGradient, start: CGPoint(x: 512, y: 966), end: CGPoint(x: 512, y: 58), options: [])
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shell)
ctx.clip()
ctx.setFillColor(NSColor.white.withAlphaComponent(0.075).cgColor)
ctx.fillEllipse(in: CGRect(x: 120, y: 790, width: 784, height: 265))
ctx.restoreGState()

func fillWhale(in rect: CGRect, colors: [NSColor], locations: [CGFloat], shadow: Bool) {
    ctx.saveGState()
    if shadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 26, color: NSColor(calibratedRed: 0.07, green: 0.05, blue: 0.35, alpha: 0.72).cgColor)
    }
    ctx.clip(to: rect, mask: maskCG)
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    ctx.restoreGState()
}

fillWhale(
    in: CGRect(x: 174, y: 204, width: 676, height: 676),
    colors: [NSColor(calibratedRed: 0.82, green: 0.87, blue: 1, alpha: 1), NSColor(calibratedRed: 0.42, green: 0.52, blue: 1, alpha: 1)],
    locations: [0, 1],
    shadow: true
)
fillWhale(
    in: CGRect(x: 184, y: 214, width: 656, height: 656),
    colors: [
        NSColor(calibratedRed: 0.88, green: 0.84, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.48, green: 0.57, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.15, blue: 1, alpha: 1)
    ],
    locations: [0, 0.5, 1],
    shadow: false
)

ctx.addPath(shell)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
ctx.setLineWidth(3)
ctx.strokePath()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("cannot encode png") }
try png.write(to: URL(fileURLWithPath: args[2]), options: .atomic)
