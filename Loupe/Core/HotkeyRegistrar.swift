import Foundation

final class HotkeyRegistrar {
    static let shared = HotkeyRegistrar()
    private init() {}

    func registerAll() {
        for action in HotkeyAction.allCases {
            reregister(action: action, definition: PreferencesStore.shared.hotkey(for: action))
        }
    }

    func reregister(action: HotkeyAction, definition: HotkeyDefinition) {
        HotkeyManager.shared.register(action, definition: definition) {
            Task { @MainActor in
                HotkeyRegistrar.shared.perform(action)
            }
        }
    }

    @MainActor
    private func perform(_ action: HotkeyAction) {
        switch action {
        case .captureRegion: CaptureCoordinator.shared.startRegionCapture()
        case .captureWindow: CaptureCoordinator.shared.startWindowCapture()
        case .captureFullScreen: CaptureCoordinator.shared.startFullScreenCapture()
        case .captureScrolling: CaptureCoordinator.shared.startScrollingCapture()
        case .colorPicker: CaptureCoordinator.shared.startColorPicker()
        }
    }
}
