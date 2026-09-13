import AppKit

final class ColorPickerManager {
    static let shared = ColorPickerManager()
    private(set) var recentColors: [NSColor] = []
    private let maxRecent = 10
    private let defaultsKey = "com.julienbarezi.loupe.recentColors"

    private init() {
        loadRecent()
    }

    func pickColor(completion: @escaping (NSColor) -> Void) {
        let sampler = NSColorSampler()
        sampler.show { [weak self] color in
            guard let self, let color = color else { return }
            self.recordAndCopy(color)
            completion(color)
        }
    }

    private func recordAndCopy(_ color: NSColor) {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hexString(for: rgbColor), forType: .string)
        recentColors.removeAll { $0.isApproximatelyEqual(to: rgbColor) }
        recentColors.insert(rgbColor, at: 0)
        if recentColors.count > maxRecent {
            recentColors.removeLast(recentColors.count - maxRecent)
        }
        saveRecent()
    }

    func hexString(for color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func saveRecent() {
        let hexes = recentColors.map { hexString(for: $0) }
        UserDefaults.standard.set(hexes, forKey: defaultsKey)
    }

    private func loadRecent() {
        guard let hexes = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else { return }
        recentColors = hexes.compactMap { NSColor(loupeHex: $0) }
    }
}

extension NSColor {
    convenience init?(loupeHex hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6, let rgb = UInt32(hexSanitized, radix: 16) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    func isApproximatelyEqual(to other: NSColor) -> Bool {
        guard let a = usingColorSpace(.sRGB), let b = other.usingColorSpace(.sRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < 0.004 &&
               abs(a.greenComponent - b.greenComponent) < 0.004 &&
               abs(a.blueComponent - b.blueComponent) < 0.004
    }
}
