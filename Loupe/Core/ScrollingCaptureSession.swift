import AppKit
import ScreenCaptureKit

@MainActor
final class ScrollingCaptureSession {
    private let display: SCDisplay
    private let region: CGRect
    private let stitcher = ScrollStitcher()
    private var timer: Timer?
    private var completion: ((NSImage?) -> Void)?
    private var hudWindow: ScrollingCaptureHUDWindow?
    private var isCapturingFrame = false

    init(display: SCDisplay, region: CGRect) {
        self.display = display
        self.region = region
    }

    func start(completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        stitcher.reset()
        let hud = ScrollingCaptureHUDWindow()
        hud.onStop = { [weak self] in self?.finish() }
        hud.show()
        hudWindow = hud
        captureFrame()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureFrame() }
        }
    }

    private func captureFrame() {
        guard !isCapturingFrame else { return }
        isCapturingFrame = true
        Task {
            defer { isCapturingFrame = false }
            if let image = try? await CaptureManager.shared.captureRegion(region, display: display),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                stitcher.addFrame(cgImage)
            }
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        hudWindow?.hide()
        hudWindow = nil
        let result = stitcher.finalImage()
        completion?(result)
        completion = nil
    }
}
