import AppKit

let outputDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("RunOnly/Assets.xcassets/AppIcon.appiconset")

let icons: [(filename: String, pixelSize: Int)] = [
    ("Icon-20@2x.png", 40),
    ("Icon-20@3x.png", 60),
    ("Icon-29@2x.png", 58),
    ("Icon-29@3x.png", 87),
    ("Icon-40@2x.png", 80),
    ("Icon-40@3x.png", 120),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-20@2x-ipad.png", 40),
    ("Icon-29@2x-ipad.png", 58),
    ("Icon-40@1x-ipad.png", 40),
    ("Icon-40@2x-ipad.png", 80),
    ("Icon-76@1x-ipad.png", 76),
    ("Icon-76@2x-ipad.png", 152),
    ("Icon-83.5@2x-ipad.png", 167),
    ("Icon-1024.png", 1024)
]

func scaled(_ value: CGFloat, for size: CGFloat) -> CGFloat {
    value * size / 1024
}

func drawIcon(size: CGSize) throws -> NSBitmapImageRep {
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
    NSColor(calibratedRed: 0.015, green: 0.025, blue: 0.055, alpha: 1).setFill()
    rect.fill()

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.015, green: 0.025, blue: 0.055, alpha: 1)
    ])!
    background.draw(in: NSBezierPath(rect: rect), angle: -22)

    let inset = scaled(118, for: size.width)
    let track = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: scaled(190, for: size.width), yRadius: scaled(190, for: size.width))
    track.lineWidth = scaled(28, for: size.width)
    NSColor(calibratedRed: 0.28, green: 0.90, blue: 0.64, alpha: 0.96).setStroke()
    track.stroke()

    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let accentArc = NSBezierPath()
    accentArc.lineWidth = scaled(34, for: size.width)
    accentArc.lineCapStyle = .round
    accentArc.appendArc(withCenter: center, radius: scaled(300, for: size.width), startAngle: 210, endAngle: 318, clockwise: false)
    NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.22, alpha: 1).setStroke()
    accentArc.stroke()

    let spark = NSBezierPath(ovalIn: CGRect(x: scaled(735, for: size.width), y: scaled(253, for: size.width), width: scaled(40, for: size.width), height: scaled(40, for: size.width)))
    NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.22, alpha: 1).setFill()
    spark.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let primaryAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: scaled(430, for: size.width), weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .kern: scaled(-6, for: size.width)
    ]
    NSAttributedString(string: "P", attributes: primaryAttributes)
        .draw(in: CGRect(x: scaled(186, for: size.width), y: scaled(250, for: size.width), width: scaled(652, for: size.width), height: scaled(480, for: size.width)))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for icon in icons {
    let size = CGSize(width: icon.pixelSize, height: icon.pixelSize)
    let rep = try drawIcon(size: size)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to build image")
    }
    try png.write(to: outputDirectoryURL.appendingPathComponent(icon.filename))
}
