import AppKit
import Carbon.HIToolbox

final class RegionSelectionView: NSView {
    var onComplete: ((CGRect?) -> Void)?

    private let backgroundImage: NSImage
    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    private var trackingArea: NSTrackingArea?
    private var mouseLocation: NSPoint = .zero

    init(frame: NSRect, backgroundImage: NSImage) {
        self.backgroundImage = backgroundImage
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        mouseLocation = current
        currentRect = NSRect(x: min(start.x, current.x), y: min(start.y, current.y),
                              width: abs(current.x - start.x), height: abs(current.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil }
        guard currentRect.width > 2, currentRect.height > 2 else {
            onComplete?(nil)
            return
        }
        onComplete?(currentRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onComplete?(nil)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        backgroundImage.draw(in: bounds)
        context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.fill(bounds)

        guard currentRect.width > 0, currentRect.height > 0 else { return }

        context.saveGState()
        context.clip(to: currentRect)
        backgroundImage.draw(in: bounds)
        context.restoreGState()

        context.setStrokeColor(Theme.accent.cgColor)
        context.setLineWidth(1.5)
        context.stroke(currentRect.insetBy(dx: 0.75, dy: 0.75))

        drawDimensionLabel(context: context)
        drawLoupe(context: context)
    }

    private func drawDimensionLabel(context: CGContext) {
        let text = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let padding: CGFloat = 6
        let labelOrigin = NSPoint(x: currentRect.minX, y: min(currentRect.maxY + 6, bounds.maxY - size.height - padding))
        let bgRect = NSRect(x: labelOrigin.x, y: labelOrigin.y, width: size.width + padding * 2, height: size.height + padding)
        let path = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        path.fill()
        text.draw(at: NSPoint(x: bgRect.minX + padding, y: bgRect.minY + padding / 2), withAttributes: attrs)
    }

    private func drawLoupe(context: CGContext) {
        let loupeSize: CGFloat = 100
        let sampleSize: CGFloat = 10
        let loupeOrigin = NSPoint(x: min(mouseLocation.x + 20, bounds.maxX - loupeSize - 8),
                                   y: min(mouseLocation.y + 20, bounds.maxY - loupeSize - 8))
        let loupeRect = NSRect(origin: loupeOrigin, size: NSSize(width: loupeSize, height: loupeSize))
        let sourceRect = NSRect(x: mouseLocation.x - sampleSize / 2, y: mouseLocation.y - sampleSize / 2,
                                 width: sampleSize, height: sampleSize)

        context.saveGState()
        let clipPath = NSBezierPath(roundedRect: loupeRect, xRadius: 8, yRadius: 8)
        clipPath.addClip()
        backgroundImage.draw(in: loupeRect, from: sourceRect, operation: .copy, fraction: 1.0)
        context.restoreGState()

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1.5)
        context.stroke(loupeRect.insetBy(dx: 0.75, dy: 0.75))

        context.setFillColor(Theme.accent.cgColor)
        context.fill(NSRect(x: loupeRect.midX - 0.5, y: loupeRect.midY - 5, width: 1, height: 10))
        context.fill(NSRect(x: loupeRect.midX - 5, y: loupeRect.midY - 0.5, width: 10, height: 1))
    }
}
