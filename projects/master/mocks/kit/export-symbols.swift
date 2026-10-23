// Renders the SF Symbols the app uses to black template PNGs for the mock kit.
// Run: swift projects/master/mocks/kit/export-symbols.swift projects/master/mocks/kit/symbols
import AppKit
let names = ["pin.fill","pin.slash","mic.fill","waveform","play.rectangle.fill","play.fill","pause.fill",
  "video.fill","arrow.left.and.right.righttriangle.left.righttriangle.right","chevron.down",
  "minus.magnifyingglass","plus.magnifyingglass","power","trash","record.circle","exclamationmark.triangle"]
let out = CommandLine.arguments[1]
for n in names {
    let cfg = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
    guard let img = NSImage(systemSymbolName: n, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { print("missing \(n)"); continue }
    let s = img.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s.width*2), pixelsHigh: Int(s.height*2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = s
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(origin: .zero, size: s))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(n).png"))
}
