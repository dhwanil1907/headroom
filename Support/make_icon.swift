// Renders the Headroom app icon (a usage gauge) into an .iconset folder.
// Usage: swift Support/make_icon.swift <output.iconset>
import AppKit

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func draw(size: CGFloat) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let scale = size / 1024
  let transform = NSAffineTransform()
  transform.scale(by: scale)
  transform.concat()

  // macOS icon body: 824pt rounded square centred in a 1024pt canvas.
  let body = NSBezierPath(
    roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
  NSGradient(colors: [color(0.19, 0.19, 0.22), color(0.07, 0.07, 0.09)])!.draw(in: body, angle: -90)

  let center = NSPoint(x: 512, y: 470)
  let radius: CGFloat = 250
  func angle(_ t: Double) -> CGFloat { CGFloat(210 - 240 * t) }
  func arc(_ from: Double, _ to: Double, _ stroke: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: angle(from), endAngle: angle(to), clockwise: true)
    path.lineWidth = width
    path.lineCapStyle = .round
    stroke.setStroke()
    path.stroke()
  }

  arc(0, 1, color(1, 1, 1, 0.14), width: 74)

  // Filled portion fades from Claude orange to Cursor blue.
  let fill = 0.62
  let steps = 60
  let orange = (r: 0.85, g: 0.47, b: 0.34), blue = (r: 0.38, g: 0.5, b: 0.95)
  for step in 0..<steps {
    let t0 = fill * Double(step) / Double(steps)
    let t1 = fill * Double(step + 1) / Double(steps)
    let mix = Double(step) / Double(steps - 1)
    let tint = color(
      orange.r + (blue.r - orange.r) * mix, orange.g + (blue.g - orange.g) * mix,
      orange.b + (blue.b - orange.b) * mix)
    arc(t0, t1 + 0.002, tint, width: 74)
  }

  // Needle and hub.
  let needleAngle = angle(fill) * .pi / 180
  let tip = NSPoint(
    x: center.x + (radius - 70) * cos(needleAngle), y: center.y + (radius - 70) * sin(needleAngle))
  let needle = NSBezierPath()
  needle.move(to: center)
  needle.line(to: tip)
  needle.lineWidth = 34
  needle.lineCapStyle = .round
  color(1, 1, 1).setStroke()
  needle.stroke()
  color(1, 1, 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: center.x - 42, y: center.y - 42, width: 84, height: 84)).fill()
  color(0.12, 0.12, 0.14).setFill()
  NSBezierPath(ovalIn: NSRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32)).fill()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("usage: make_icon.swift <output.iconset>\n".utf8))
  exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    let png = draw(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
    try png.write(to: output.appendingPathComponent(name))
  }
}
