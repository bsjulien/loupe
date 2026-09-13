import AppKit

final class PinnedWindowController: NSWindowController, NSWindowDelegate {
    private static var open: [PinnedWindowController] = []
    private var pinnedImage: NSImage?

    static func open(image: NSImage) {
        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyUpOrDown

        let window = NSPanel(contentRect: NSRect(origin: .zero, size: image.size),
                              styleMask: [.nonactivatingPanel, .resizable, .titled, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.contentView = imageView
        window.contentAspectRatio = image.size
        window.center()

        let controller = PinnedWindowController(window: window)
        window.delegate = controller
        controller.pinnedImage = image
        Self.open.append(controller)
        controller.showWindow(nil)
        controller.installContextMenu(imageView: imageView)
    }

    private func installContextMenu(imageView: NSImageView) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copyImage), keyEquivalent: "")
        menu.addItem(withTitle: "Save As…", action: #selector(saveImage), keyEquivalent: "")
        menu.addItem(withTitle: "Close", action: #selector(closeSelf), keyEquivalent: "")
        for item in menu.items { item.target = self }
        imageView.menu = menu
    }

    @objc private func copyImage() {
        guard let image = pinnedImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    @objc private func saveImage() {
        guard let image = pinnedImage else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Loupe Screenshot.png"
        panel.directoryURL = PreferencesStore.shared.saveFolderURL
        if panel.runModal() == .OK, let url = panel.url,
           let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }

    @objc private func closeSelf() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        Self.open.removeAll { $0 === self }
    }
}
