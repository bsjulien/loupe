import SwiftUI
import AppKit
import Carbon.HIToolbox

enum HotkeyModifierConverter {
    static func carbonModifiers(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if cocoa.contains(.command) { carbon |= UInt32(cmdKey) }
        if cocoa.contains(.option) { carbon |= UInt32(optionKey) }
        if cocoa.contains(.control) { carbon |= UInt32(controlKey) }
        if cocoa.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}

struct ShortcutRecorderField: NSViewRepresentable {
    let action: HotkeyAction

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.action = action
        view.definition = PreferencesStore.shared.hotkey(for: action)
        view.onChange = { newDefinition in
            PreferencesStore.shared.setHotkey(newDefinition, for: action)
            HotkeyRegistrar.shared.reregister(action: action, definition: newDefinition)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {}
}

final class ShortcutRecorderView: NSView {
    var action: HotkeyAction = .captureRegion
    var definition: HotkeyDefinition = HotkeyAction.captureRegion.defaultDefinition {
        didSet { needsDisplay = true }
    }
    var onChange: ((HotkeyDefinition) -> Void)?
    private var isRecording = false

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        if event.keyCode == 51 || event.keyCode == 117 || event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            needsDisplay = true
            return
        }
        let modifiers = HotkeyModifierConverter.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else { return }
        let newDefinition = HotkeyDefinition(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        definition = newDefinition
        isRecording = false
        onChange?(newDefinition)
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill: NSColor = isRecording ? Theme.accent.withAlphaComponent(0.15) : Theme.background
        fill.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        path.fill()
        Theme.hairline.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Press shortcut…" : definition.displayString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: Theme.textPrimary
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }
}
