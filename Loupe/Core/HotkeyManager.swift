import Carbon.HIToolbox
import AppKit

struct HotkeyDefinition: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var parts = ""
        if modifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        parts += KeyCodeTranslator.name(for: keyCode)
        return parts
    }
}

enum HotkeyAction: String, CaseIterable, Codable {
    case captureRegion, captureWindow, captureFullScreen, captureScrolling, colorPicker

    var title: String {
        switch self {
        case .captureRegion: return "Capture Region"
        case .captureWindow: return "Capture Window"
        case .captureFullScreen: return "Capture Full Screen"
        case .captureScrolling: return "Scrolling Capture"
        case .colorPicker: return "Color Picker"
        }
    }

    var defaultDefinition: HotkeyDefinition {
        switch self {
        case .captureRegion:
            return HotkeyDefinition(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(controlKey | shiftKey))
        case .captureWindow:
            return HotkeyDefinition(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(controlKey | shiftKey))
        case .captureFullScreen:
            return HotkeyDefinition(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(controlKey | shiftKey))
        case .captureScrolling:
            return HotkeyDefinition(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(controlKey | shiftKey))
        case .colorPicker:
            return HotkeyDefinition(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | shiftKey))
        }
    }
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var actionIDs: [HotkeyAction: UInt32] = [:]
    private var nextID: UInt32 = 1
    private let signature: OSType = 0x4C555045

    private init() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return OSStatus(eventNotHandledErr) }
            manager.handlers[hotKeyID.id]?()
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    func register(_ action: HotkeyAction, definition: HotkeyDefinition, handler: @escaping () -> Void) {
        unregister(action)
        let id = nextID
        nextID += 1
        actionIDs[action] = id
        handlers[id] = handler
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(definition.keyCode, definition.modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref = ref {
            hotKeyRefs[action] = ref
        }
    }

    func unregister(_ action: HotkeyAction) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotKeyRefs[action] = nil
        }
        if let id = actionIDs[action] {
            handlers[id] = nil
            actionIDs[action] = nil
        }
    }

    func unregisterAll() {
        for action in HotkeyAction.allCases { unregister(action) }
    }
}
