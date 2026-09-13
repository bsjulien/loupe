import AppKit
import SwiftUI

enum Theme {
    static let background = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.13, alpha: 1.0)
            : NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)
    }

    static let hairline = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.12)
            : NSColor(white: 0.0, alpha: 0.12)
    }

    static let textPrimary = NSColor.labelColor

    static let accent = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.80, green: 0.65, blue: 0.55, alpha: 1.0)
            : NSColor(calibratedRed: 0.35, green: 0.30, blue: 0.27, alpha: 1.0)
    }

    static let cornerRadius: CGFloat = 8
    static let padding: CGFloat = 12

    static let backgroundColor = Color(background)
    static let hairlineColor = Color(hairline)
    static let accentColor = Color(accent)
}
