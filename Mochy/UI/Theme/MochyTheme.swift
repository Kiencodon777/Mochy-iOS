import SwiftUI

public struct MochyTheme {
    public static let background = Color(hex: "0D0D11")
    public static let surface = Color(hex: "181820")
    public static let surfaceHighlight = Color(hex: "252533")
    public static let accent = Color(hex: "FF4D79")
    public static let textPrimary = Color.white
    public static let textSecondary = Color(hex: "8E8E93")
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
