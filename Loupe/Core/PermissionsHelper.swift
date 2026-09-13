import AppKit
import CoreGraphics

enum PermissionsHelper {
    static func hasScreenRecordingAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecordingAccess() {
        CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    @MainActor
    static func ensureAccessOrPrompt() -> Bool {
        if hasScreenRecordingAccess() { return true }
        // Bring the app forward first: this is an accessory (menu-bar-only) app that
        // never activates itself, so a modal alert shown without this can render behind
        // every other window on screen and look like the app did nothing at all.
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Needed"
        alert.informativeText = "Loupe needs Screen Recording permission to take screenshots. Grant access in System Settings, then relaunch Loupe."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn {
            requestScreenRecordingAccess()
            openScreenRecordingSettings()
        }
        return false
    }
}
