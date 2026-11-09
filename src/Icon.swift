import AppKit

enum DualPhoneIcon {
    /// Rear (left) FULL continuous solid white first — never punch a hole.
    /// Then clip to rear ∩ front INTERIOR and paint that region frosted (~48% white).
    /// Front (right) hollow outline + home indicator on top.
    /// Overlap ≈ 1/2 phone width (half).
    /// Vertical offset ≈ 1/4 phone height: rear higher, front lower.
    /// Bitmap context origin is bottom-left (y up).
    static func make(template: Bool = true) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let scale: CGFloat = 2
        let pxW = Int(size.width * scale)
        let pxH = Int(size.height * scale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxW,
            pixelsHigh: pxH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: size)
        }
        NSGraphicsContext.current = nsCtx
        let cg = nsCtx.cgContext
        cg.setShouldAntialias(true)
        cg.interpolationQuality = .high
        cg.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let phoneW: CGFloat = 11.0
        let phoneH: CGFloat = 16.0
        let corner: CGFloat = 2.45
        let stroke: CGFloat = 1.35
        let overlap: CGFloat = phoneW * 0.50        // ≈ 1/2 width
        let heightDiff: CGFloat = phoneH * 0.25     // ≈ 1/4 phone length

        // y-up: front LOWER (smaller y), rear HIGHER (larger y)
        // Keep composite roughly centered after half-overlap
        let frontY: CGFloat = 0.55
        let rearY: CGFloat = frontY + heightDiff
        let totalW = phoneW * 2.0 - overlap
        let rearX: CGFloat = (size.width - totalW) / 2.0
        let frontX = rearX + phoneW - overlap

        let rearRect = CGRect(x: rearX, y: rearY, width: phoneW, height: phoneH)
        let frontRect = CGRect(x: frontX, y: frontY, width: phoneW, height: phoneH)

        func roundedPhonePath(_ r: CGRect) -> CGPath {
            CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil)
        }

        // Soft inset for front INTERIOR (inside the stroke ring)
        let frontInterior = frontRect.insetBy(dx: stroke * 0.85, dy: stroke * 0.85)

        // 1) Entire rear phone: continuous solid white — NO clear / NO hole
        cg.setFillColor(NSColor.white.withAlphaComponent(1.0).cgColor)
        cg.addPath(roundedPhonePath(rearRect))
        cg.fillPath()

        // 2) Frost: rear ∩ front INTERIOR → replace with ~48% white (lighter / frosted)
        // Soft edge via slight extra inset + antialias
        cg.saveGState()
        cg.addPath(roundedPhonePath(rearRect))
        cg.clip()
        let frostInterior = frontInterior.insetBy(dx: 0.15, dy: 0.15)
        cg.addPath(roundedPhonePath(frostInterior))
        cg.clip()
        // Destination-in style replace: paint frosted white over the clipped overlap
        cg.setBlendMode(.copy)
        cg.setFillColor(NSColor.white.withAlphaComponent(0.48).cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        cg.restoreGState()

        // 3) Front hollow outline on top
        cg.setBlendMode(.normal)
        cg.setStrokeColor(NSColor.white.withAlphaComponent(1.0).cgColor)
        cg.setLineWidth(stroke)
        cg.setLineJoin(.round)
        cg.setLineCap(.round)
        cg.addPath(roundedPhonePath(frontRect.insetBy(dx: stroke / 2, dy: stroke / 2)))
        cg.strokePath()

        // 4) Home indicator near BOTTOM of front phone
        let homeW = phoneW * 0.40
        let homeH: CGFloat = 1.15
        let homeRect = CGRect(
            x: frontRect.midX - homeW / 2,
            y: frontRect.minY + 1.9,
            width: homeW,
            height: homeH
        )
        cg.setFillColor(NSColor.white.withAlphaComponent(1.0).cgColor)
        cg.addPath(CGPath(roundedRect: homeRect, cornerWidth: homeH / 2, cornerHeight: homeH / 2, transform: nil))
        cg.fillPath()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = template
        return image
    }
}
