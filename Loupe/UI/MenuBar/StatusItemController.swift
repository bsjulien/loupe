import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "viewfinder.circle", accessibilityDescription: "Loupe")
        image?.isTemplate = true
        statusItem.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        addItem(menu, "Capture Region", action: #selector(captureRegion), hotkeyAction: .captureRegion)
        addItem(menu, "Capture Window", action: #selector(captureWindow), hotkeyAction: .captureWindow)
        addItem(menu, "Capture Full Screen", action: #selector(captureFullScreen), hotkeyAction: .captureFullScreen)
        addItem(menu, "Scrolling Capture", action: #selector(captureScrolling), hotkeyAction: .captureScrolling)
        menu.addItem(.separator())
        addItem(menu, "Pick Color", action: #selector(pickColor), hotkeyAction: .colorPicker)

        if !ColorPickerManager.shared.recentColors.isEmpty {
            let recentMenu = NSMenu()
            for color in ColorPickerManager.shared.recentColors {
                let hex = ColorPickerManager.shared.hexString(for: color)
                let item = NSMenuItem(title: hex, action: #selector(copyRecentColor(_:)), keyEquivalent: "")
                item.target = self
                item.image = swatchImage(for: color)
                item.representedObject = hex
                recentMenu.addItem(item)
            }
            let recentItem = NSMenuItem(title: "Recent Colors", action: nil, keyEquivalent: "")
            recentItem.submenu = recentMenu
            menu.addItem(recentItem)
        }

        menu.addItem(.separator())
        let historyItem = NSMenuItem(title: "Recent Screenshots", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu()
        for item in HistoryStore.shared.items.prefix(8) {
            let menuItem = NSMenuItem(title: item.fileName, action: #selector(openHistoryItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            if let thumb = HistoryStore.shared.image(for: item) {
                let resized = NSImage(size: NSSize(width: 32, height: 20))
                resized.lockFocus()
                thumb.draw(in: NSRect(origin: .zero, size: resized.size))
                resized.unlockFocus()
                menuItem.image = resized
            }
            historyMenu.addItem(menuItem)
        }
        if historyMenu.items.isEmpty {
            historyMenu.addItem(withTitle: "No screenshots yet", action: nil, keyEquivalent: "")
        }
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        menu.addItem(.separator())
        let prefsItem = menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        let quitItem = menu.addItem(withTitle: "Quit Loupe", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
    }

    private func addItem(_ menu: NSMenu, _ title: String, action: Selector, hotkeyAction: HotkeyAction) {
        let shortcut = PreferencesStore.shared.hotkey(for: hotkeyAction).displayString
        let item = NSMenuItem(title: "\(title)  (\(shortcut))", action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func swatchImage(for color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 14))
        image.lockFocus()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 14, height: 14), xRadius: 3, yRadius: 3).fill()
        image.unlockFocus()
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    @objc private func captureRegion() { CaptureCoordinator.shared.startRegionCapture() }
    @objc private func captureWindow() { CaptureCoordinator.shared.startWindowCapture() }
    @objc private func captureFullScreen() { CaptureCoordinator.shared.startFullScreenCapture() }
    @objc private func captureScrolling() { CaptureCoordinator.shared.startScrollingCapture() }
    @objc private func pickColor() { CaptureCoordinator.shared.startColorPicker() }
    @objc private func openPreferences() { PreferencesWindowController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func copyRecentColor(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    @objc private func openHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HistoryItem else { return }
        NSWorkspace.shared.open(HistoryStore.shared.url(for: item))
    }
}
