import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let iconset = root.appendingPathComponent("build/Lunelio.iconset")
let chrome = root.appendingPathComponent("BrowserExtension/icons")
let appIcons = resources.appendingPathComponent("Assets.xcassets/LunelioIcon.appiconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: chrome, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIcons, withIntermediateDirectories: true)

let mark = CGMutablePath()
mark.move(to: CGPoint(x: 480, y: 120))
mark.addCurve(to: CGPoint(x: 550, y: 60), control1: CGPoint(x: 480, y: 80), control2: CGPoint(x: 515, y: 60))
mark.addCurve(to: CGPoint(x: 780, y: 165), control1: CGPoint(x: 665, y: 60), control2: CGPoint(x: 725, y: 105))
mark.addCurve(to: CGPoint(x: 890, y: 225), control1: CGPoint(x: 825, y: 210), control2: CGPoint(x: 855, y: 225))
mark.addCurve(to: CGPoint(x: 865, y: 325), control1: CGPoint(x: 930, y: 225), control2: CGPoint(x: 900, y: 295))
mark.addCurve(to: CGPoint(x: 570, y: 230), control1: CGPoint(x: 790, y: 385), control2: CGPoint(x: 705, y: 330))
mark.addLine(to: CGPoint(x: 570, y: 625))
mark.addCurve(to: CGPoint(x: 350, y: 880), control1: CGPoint(x: 570, y: 785), control2: CGPoint(x: 465, y: 880))
mark.addCurve(to: CGPoint(x: 80, y: 635), control1: CGPoint(x: 195, y: 880), control2: CGPoint(x: 80, y: 775))
mark.addCurve(to: CGPoint(x: 420, y: 368), control1: CGPoint(x: 80, y: 465), control2: CGPoint(x: 235, y: 350))
mark.addCurve(to: CGPoint(x: 245, y: 565), control1: CGPoint(x: 310, y: 390), control2: CGPoint(x: 230, y: 485))
mark.addCurve(to: CGPoint(x: 360, y: 705), control1: CGPoint(x: 255, y: 650), control2: CGPoint(x: 300, y: 705))
mark.addCurve(to: CGPoint(x: 480, y: 590), control1: CGPoint(x: 420, y: 705), control2: CGPoint(x: 480, y: 650))
mark.addLine(to: CGPoint(x: 480, y: 120))
mark.closeSubpath()
precondition(mark.contains(CGPoint(x: 150, y: 650)))
precondition(mark.contains(CGPoint(x: 520, y: 500)))
precondition(!mark.contains(CGPoint(x: 350, y: 520)))
precondition(!mark.contains(CGPoint(x: 0, y: 0)))

let green = CGColor(red: 30 / 255, green: 215 / 255, blue: 96 / 255, alpha: 1)
let navy = CGColor(red: 11 / 255, green: 18 / 255, blue: 32 / 255, alpha: 1)
func png(size: Int, tile: Bool = false, template: Bool = false) throws -> Data {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1000, y: CGFloat(size) / 1000)
    context.translateBy(x: 0, y: 1000)
    context.scaleBy(x: 1, y: -1)
    if tile {
        context.setFillColor(navy)
        context.addPath(CGPath(roundedRect: CGRect(x: 62.5, y: 62.5, width: 875, height: 875),
            cornerWidth: 205, cornerHeight: 205, transform: nil))
        context.fillPath()
        context.translateBy(x: 140, y: 140)
        context.scaleBy(x: 0.72, y: 0.72)
    }
    context.setFillColor(template ? CGColor(gray: 0, alpha: 1) : green)
    context.addPath(mark)
    context.fillPath()
    guard let image = context.makeImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}
try png(size: 512).write(to: resources.appendingPathComponent("BrandMark.png"))
try png(size: 36, template: true).write(to: resources.appendingPathComponent("MenuBarIcon.png"))
try png(size: 1024, tile: true).write(to: root.appendingPathComponent("Design/Branding/Selected/AppIcon-1024.png"))
for (name, size) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                     ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256),
                     ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let data = try png(size: size, tile: true)
    precondition(NSBitmapImageRep(data: data)?.pixelsWide == size)
    try data.write(to: iconset.appendingPathComponent(name + ".png"))
    try data.write(to: appIcons.appendingPathComponent(name + ".png"))
}
for size in [16, 32, 48, 128] {
    try png(size: size).write(to: chrome.appendingPathComponent("icon\(size).png"))
}
var commands: [String] = []
func point(_ value: CGPoint) -> String { "\(value.x) \(value.y)" }
mark.applyWithBlock { element in
    let e = element.pointee
    switch e.type {
    case .moveToPoint: commands.append("M" + point(e.points[0]))
    case .addLineToPoint: commands.append("L" + point(e.points[0]))
    case .addCurveToPoint: commands.append("C" + point(e.points[0]) + " " + point(e.points[1]) + " " + point(e.points[2]))
    case .closeSubpath: commands.append("Z")
    default: preconditionFailure("Unexpected mark geometry")
    }
}
let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1000 1000\" role=\"img\" aria-label=\"Lunelio moon and music symbol\"><path fill=\"#1ED760\" d=\"\(commands.joined(separator: " "))\"/></svg>"
try svg.write(to: root.appendingPathComponent("Design/Branding/Selected/BrandMark.svg"), atomically: true, encoding: .utf8)
print("Created app icon sizes, template menu icon, widget mark and Chrome icons.")
