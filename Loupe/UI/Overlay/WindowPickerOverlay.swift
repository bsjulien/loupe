import AppKit
import ScreenCaptureKit

final class WindowPickerOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.001)
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }
}

final class WindowPickerOverlayView: NSView {
    var onComplete: ((SCWindow?) -> Void)?

    private let windows: [SCWindow]
    private let screen: NSScreen
    private var hoveredWindow: SCWindow?
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, windows: [SCWindow], screen: NSScreen) {
        self.windows = windows
        self.screen = screen
        super.init(frame: frame)
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
        let point = convert(event.locationInWindow, from: nil)
        let flipped = CGPoint(x: point.x, y: screen.frame.height - point.y)
        hoveredWindow = windows.first { $0.frame.contains(flipped) }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onComplete?(hoveredWindow)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onComplete?(nil)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(0.25).cgColor)
        context.fill(bounds)

        guard let hovered = hoveredWindow else { return }
        let localRect = NSRect(x: hovered.frame.minX, y: screen.frame.height - hovered.frame.maxY,
                                width: hovered.frame.width, height: hovered.frame.height)
        context.setStrokeColor(Theme.accent.cgColor)
        context.setLineWidth(3)
        context.stroke(localRect.insetBy(dx: 1.5, dy: 1.5))
    }
}
