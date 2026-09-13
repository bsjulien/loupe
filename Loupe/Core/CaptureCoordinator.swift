import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()
    private var overlayWindows: [NSWindow] = []
    private var scrollingSession: ScrollingCaptureSession?

    private init() {}

    func startRegionCapture() {
        guard PermissionsHelper.ensureAccessOrPrompt() else { return }
        Task {
            do {
                guard let screen = NSScreen.main else { return }
                let display = try await self.matchingDisplay(for: screen)
                let backdrop = try await CaptureManager.shared.captureFullScreen(display: display)
                self.presentSelectionOverlay(screen: screen, backdrop: backdrop) { rect in
                    guard let rect else { return }
                    Task {
                        let topLeftRect = ScreenCoordinates.topLeftOriginRect(fromBottomLeftOriginRect: rect, screenHeight: screen.frame.height)
                        if let image = try? await CaptureManager.shared.captureRegion(topLeftRect, display: display) {
                            self.finishCapture(image)
                        }
                    }
                }
            } catch {
                self.showError(error)
            }
        }
    }

    func startWindowCapture() {
        guard PermissionsHelper.ensureAccessOrPrompt() else { return }
        Task {
            do {
                let content = try await CaptureManager.shared.availableContent()
                let windows = content.windows.filter {
                    $0.isOnScreen && $0.frame.width > 40 && $0.frame.height > 40 && $0.owningApplication != nil
                }
                self.presentWindowPicker(windows: windows) { selected in
                    guard let selected else { return }
                    Task {
                        if let image = try? await CaptureManager.shared.captureWindow(selected) {
                            self.finishCapture(image)
                        }
                    }
                }
            } catch {
                self.showError(error)
            }
        }
    }

    func startFullScreenCapture() {
        guard PermissionsHelper.ensureAccessOrPrompt() else { return }
        Task {
            do {
                let display = try await CaptureManager.shared.mainDisplay()
                let image = try await CaptureManager.shared.captureFullScreen(display: display)
                self.finishCapture(image)
            } catch {
                self.showError(error)
            }
        }
    }

    func startScrollingCapture() {
        guard PermissionsHelper.ensureAccessOrPrompt() else { return }
        Task {
            guard let screen = NSScreen.main else { return }
            do {
                let display = try await self.matchingDisplay(for: screen)
                let backdrop = try await CaptureManager.shared.captureFullScreen(display: display)
                self.presentSelectionOverlay(screen: screen, backdrop: backdrop) { rect in
                    guard let rect else { return }
                    let topLeftRect = ScreenCoordinates.topLeftOriginRect(fromBottomLeftOriginRect: rect, screenHeight: screen.frame.height)
                    let session = ScrollingCaptureSession(display: display, region: topLeftRect)
                    self.scrollingSession = session
                    session.start { [weak self] image in
                        self?.scrollingSession = nil
                        if let image { self?.finishCapture(image) }
                    }
                }
            } catch {
                self.showError(error)
            }
        }
    }

    func startColorPicker() {
        ColorPickerManager.shared.pickColor { color in
            ColorPickerHUD.show(color: color)
        }
    }

    private func matchingDisplay(for screen: NSScreen) async throws -> SCDisplay {
        let content = try await CaptureManager.shared.availableContent()
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let display = content.displays.first(where: { $0.displayID == number }) {
            return display
        }
        return try await CaptureManager.shared.mainDisplay()
    }

    private func presentSelectionOverlay(screen: NSScreen, backdrop: NSImage, completion: @escaping (CGRect?) -> Void) {
        let window = RegionSelectionOverlayWindow(screen: screen)
        let view = RegionSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), backgroundImage: backdrop)
        view.onComplete = { [weak self] rect in
            self?.closeOverlays()
            completion(rect)
        }
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(view)
        overlayWindows = [window]
    }

    private func presentWindowPicker(windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        guard let screen = NSScreen.main else { completion(nil); return }
        let window = WindowPickerOverlayWindow(screen: screen)
        let view = WindowPickerOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), windows: windows, screen: screen)
        view.onComplete = { [weak self] selected in
            self?.closeOverlays()
            completion(selected)
        }
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(view)
        overlayWindows = [window]
    }

    private func closeOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows = []
    }

    private func finishCapture(_ image: NSImage) {
        if PreferencesStore.shared.autoCopyOnCapture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
        _ = HistoryStore.shared.save(image: image)
        AnnotationWindowController.open(image: image)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = "\(error)"
        alert.runModal()
    }
}
