import SwiftUI

extension Color {
    public static let obsidianBackground = Color(hex: "0B0D12")
    public static let obsidianSurface = Color(hex: "151922")
    public static let obsidianSurfaceVariant = Color(hex: "1E2330")
    public static let obsidianBorder = Color(hex: "232938")
    
    public static let primaryBlue = Color(hex: "4F8CFF")
    public static let primaryBlueDark = Color(hex: "2563EB")
    public static let recordingRed = Color(hex: "FF4D5A")
    public static let recordingRedDark = Color(hex: "D62839")
    public static let successGreen = Color(hex: "10B981")
    
    public static let textPrimary = Color(hex: "F3F5FA")
    public static let textSecondary = Color(hex: "9DA5B8")
    public static let textMuted = Color(hex: "6B7280")
    
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
