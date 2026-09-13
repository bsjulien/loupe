import CoreGraphics

enum ScreenCoordinates {
    /// AppKit view/screen geometry uses a bottom-left origin. ScreenCaptureKit's
    /// SCStreamConfiguration.sourceRect expects a top-left origin rect relative to the
    /// same display. This converts between the two.
    static func topLeftOriginRect(fromBottomLeftOriginRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.origin.x, y: screenHeight - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
}
