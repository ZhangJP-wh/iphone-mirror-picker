import AppKit

/// Build a synthetic icon preview PNG (no screen capture; no personal desktop).
/// Usage: swiftc -framework AppKit -o /tmp/export_preview Icon.swift ExportPreview.swift && /tmp/export_preview [outdir]
@main
struct ExportPreview {
    static func main() {
        let args = CommandLine.arguments
        let outDir = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let img = DualPhoneIcon.make(template: true)
        let scale: CGFloat = 16
        let w = Int(22 * scale), h = Int(22 * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fputs("bitmap failed\n", stderr)
            exit(1)
        }
        rep.size = NSSize(width: 22, height: 22)
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            // Neutral dark grey — mimics a menubar without capturing the real desktop
            NSColor(white: 0.18, alpha: 1).setFill()
            NSBezierPath.fill(NSRect(x: 0, y: 0, width: 22, height: 22))
            img.draw(
                in: NSRect(x: 0, y: 0, width: 22, height: 22),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else {
            fputs("png failed\n", stderr)
            exit(1)
        }
        let path = (outDir as NSString).appendingPathComponent("icon-preview.png")
        try! data.write(to: URL(fileURLWithPath: path))
        print("wrote", path)
    }
}
