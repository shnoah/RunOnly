import AppKit

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("RunOnly/Assets.xcassets/AppIcon.appiconset/Icon-1024.png")
let size = CGSize(width: 1024, height: 1024)

guard
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    fatalError("Failed to create bitmap")
}

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current = context

let rect = CGRect(origin: .zero, size: size)

let bg = NSBezierPath(roundedRect: rect, xRadius: 230, yRadius: 230)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.16, alpha: 1),
    NSColor(calibratedRed: 0.01, green: 0.03, blue: 0.10, alpha: 1)
])!
background.draw(in: bg, angle: -18)

let outerTrack = NSBezierPath(roundedRect: rect.insetBy(dx: 110, dy: 110), xRadius: 180, yRadius: 180)
outerTrack.lineWidth = 26
NSColor(calibratedRed: 0.29, green: 0.88, blue: 0.63, alpha: 0.95).setStroke()
outerTrack.stroke()

let paceArc = NSBezierPath()
paceArc.lineWidth = 28
paceArc.lineCapStyle = .round
let center = CGPoint(x: 512, y: 512)
paceArc.appendArc(withCenter: center, radius: 282, startAngle: 218, endAngle: 320, clockwise: false)
NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.20, alpha: 1).setStroke()
paceArc.stroke()

let paceDot = NSBezierPath(ovalIn: CGRect(x: 737, y: 250, width: 34, height: 34))
NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.20, alpha: 1).setFill()
paceDot.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 430, weight: .black),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
    .kern: -12
]
NSAttributedString(string: "R", attributes: attributes).draw(in: CGRect(x: 186, y: 255, width: 652, height: 480))

NSGraphicsContext.restoreGraphicsState()

guard
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Failed to build image")
}

try png.write(to: outputURL)
