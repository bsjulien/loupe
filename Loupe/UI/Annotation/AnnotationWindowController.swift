import AppKit
import SwiftUI

final class AnnotationWindowController: NSWindowController, NSWindowDelegate {
    private static var openControllers: [AnnotationWindowController] = []

    static func open(image: NSImage) {
        let canvas = AnnotationCanvasView(image: image)
        let contentView = AnnotationEditorView(canvas: canvas)
        let hosting = NSHostingView(rootView: contentView)

        let width = min(max(image.size.width, 480), 1400)
        let height = min(max(image.size.height, 360), 1000) + 96
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                               styleMask: [.titled, .closable, .resizable, .miniaturizable],
                               backing: .buffered, defer: false)
        window.title = "Loupe"
        window.contentView = hosting
        window.center()

        let controller = AnnotationWindowController(window: window)
        window.delegate = controller
        openControllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.onClose = {
            openControllers.removeAll { $0 === controller }
        }
    }

    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
