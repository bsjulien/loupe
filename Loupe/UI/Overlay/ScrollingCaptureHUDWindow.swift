import AppKit
import SwiftUI

final class ScrollingCaptureHUDWindow {
    private var panel: NSPanel?
    var onStop: (() -> Void)?

    func show() {
        let hostingView = NSHostingView(rootView: ScrollingCaptureHUDView(onStop: { [weak self] in
            self?.onStop?()
        }))
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 110),
                             styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                             backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.contentView = hostingView
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ScrollingCaptureHUDView: View {
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Scrolling Capture")
                .font(.system(size: 13, weight: .semibold))
            Text("Scroll the window now. Click Stop when you reach the bottom.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Stop & Stitch", action: onStop)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentColor)
        }
        .padding(16)
        .frame(width: 280)
        .background(Theme.backgroundColor)
    }
}
