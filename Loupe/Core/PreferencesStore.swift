import Foundation
import Combine
import ServiceManagement

final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    @Published var autoCopyOnCapture: Bool {
        didSet { UserDefaults.standard.set(autoCopyOnCapture, forKey: Keys.autoCopy) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    @Published var saveFolderURL: URL {
        didSet { UserDefaults.standard.set(saveFolderURL, forKey: Keys.saveFolder) }
    }
    @Published var hotkeys: [HotkeyAction: HotkeyDefinition] {
        didSet { saveHotkeys() }
    }

    private enum Keys {
        static let autoCopy = "autoCopyOnCapture"
        static let launchAtLogin = "launchAtLogin"
        static let saveFolder = "saveFolderURL"
        static let hotkeys = "hotkeyDefinitions"
    }

    private init() {
        let defaults = UserDefaults.standard
        autoCopyOnCapture = defaults.object(forKey: Keys.autoCopy) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false

        if let url = defaults.url(forKey: Keys.saveFolder) {
            saveFolderURL = url
        } else {
            let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            saveFolderURL = picturesURL.appendingPathComponent("Loupe")
        }

        if let data = defaults.data(forKey: Keys.hotkeys),
           let decoded = try? JSONDecoder().decode([String: HotkeyDefinition].self, from: data) {
            var result: [HotkeyAction: HotkeyDefinition] = [:]
            for action in HotkeyAction.allCases {
                result[action] = decoded[action.rawValue] ?? action.defaultDefinition
            }
            hotkeys = result
        } else {
            var result: [HotkeyAction: HotkeyDefinition] = [:]
            for action in HotkeyAction.allCases {
                result[action] = action.defaultDefinition
            }
            hotkeys = result
        }
    }

    private func saveHotkeys() {
        var encoded: [String: HotkeyDefinition] = [:]
        for (action, def) in hotkeys {
            encoded[action.rawValue] = def
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: Keys.hotkeys)
        }
    }

    func hotkey(for action: HotkeyAction) -> HotkeyDefinition {
        hotkeys[action] ?? action.defaultDefinition
    }

    func setHotkey(_ definition: HotkeyDefinition, for action: HotkeyAction) {
        hotkeys[action] = definition
    }

    private func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("Loupe: failed to update launch-at-login: \(error)")
            }
        }
    }
}
