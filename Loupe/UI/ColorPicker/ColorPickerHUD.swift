import AppKit

enum ColorPickerHUD {
    static func show(color: NSColor) {
        let hex = ColorPickerManager.shared.hexString(for: color)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 180, height: 60),
                             styleMask: [.nonactivatingPanel, .borderless],
                             backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true

        let view = ColorHUDView(frame: NSRect(x: 0, y: 0, width: 180, height: 60), color: color, hex: hex)
        panel.contentView = view

        if let screen = NSScreen.main {
            let origin = NSPoint(x: screen.frame.midX - 90, y: screen.frame.midY - 30)
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            panel.orderOut(nil)
        }
    }
}

private final class ColorHUDView: NSView {
    private let color: NSColor
    private let hex: String

    init(frame: NSRect, color: NSColor, hex: String) {
        self.color = color
        self.hex = hex
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        Theme.background.setFill()
        path.fill()
        Theme.hairline.setStroke()
        path.lineWidth = 1
        path.stroke()

        let swatchRect = NSRect(x: 14, y: bounds.height / 2 - 12, width: 24, height: 24)
        let swatch = NSBezierPath(roundedRect: swatchRect, xRadius: 5, yRadius: 5)
        color.setFill()
        swatch.fill()
        Theme.hairline.setStroke()
        swatch.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: Theme.textPrimary
        ]
        hex.draw(at: NSPoint(x: swatchRect.maxX + 12, y: bounds.height / 2 - 8), withAttributes: attrs)
    }
}
