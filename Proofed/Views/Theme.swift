import SwiftUI
import UIKit

/// Palette: pizza-steel charcoal, semolina, basil. Light/dark adaptive without an asset catalog.
enum Theme {
    static let steel = dynamic(light: 0x2B3036, dark: 0xE6E8EA)
    static let semolina = Color(hex: 0xD9A62E)
    static let basil = dynamic(light: 0x3E6A48, dark: 0x7FB08A)
    static let surface = dynamic(light: 0xF3F4F2, dark: 0x1B1D20)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x25282C)
    static let muted = Color.secondary

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}
