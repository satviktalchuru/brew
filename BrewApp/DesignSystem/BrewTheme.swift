import SwiftUI

enum BrewTheme {
    enum Color {
        static let background = SwiftUI.Color(hex: "#F5F0E8")
        static let surface = SwiftUI.Color(hex: "#FDFAF5")
        static let raisedSurface = SwiftUI.Color(hex: "#FFFFFF")
        static let textPrimary = SwiftUI.Color(hex: "#1A1208")
        static let textSecondary = SwiftUI.Color(hex: "#6B5E4E")
        static let textTertiary = SwiftUI.Color(hex: "#A8997F")
        static let accent = SwiftUI.Color(hex: "#C65B1A")
        static let accentLight = SwiftUI.Color(hex: "#F2D4B8")
        static let roastLight = SwiftUI.Color(hex: "#D4A96A")
        static let roastMedium = SwiftUI.Color(hex: "#8B5E3C")
        static let roastDark = SwiftUI.Color(hex: "#2C1810")
        static let success = SwiftUI.Color(hex: "#4A7C59")
        static let border = SwiftUI.Color(hex: "#E2D8C8")

        static func roast(_ roast: Roast) -> SwiftUI.Color {
            switch roast {
            case .light:
                return roastLight
            case .medium:
                return roastMedium
            case .dark:
                return roastDark
            case .unknown:
                return textTertiary
            }
        }
    }

    enum Font {
        static func heading(size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .custom("Georgia", size: size, relativeTo: .title).weight(weight)
        }

        static let largeTitle = heading(size: 34, weight: .bold)
        static let title = heading(size: 28, weight: .bold)
        static let title2 = heading(size: 22, weight: .semibold)
        static let title3 = heading(size: 18, weight: .semibold)
        static let body = SwiftUI.Font.system(.body, design: .default)
        static let bodySemibold = SwiftUI.Font.system(.body, design: .default).weight(.semibold)
        static let callout = SwiftUI.Font.system(.callout, design: .default)
        static let footnote = SwiftUI.Font.system(.footnote, design: .default)
        static let caption = SwiftUI.Font.system(.caption, design: .default)
        static let captionSemibold = SwiftUI.Font.system(.caption, design: .default).weight(.semibold)
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 16
        static let md: CGFloat = 24
        static let lg: CGFloat = 32
        static let xl: CGFloat = 48
        static let xxl: CGFloat = 64
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let cleanedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double

        switch cleanedHex.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            opacity = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            opacity = Double(value & 0xFF) / 255
        default:
            red = 0
            green = 0
            blue = 0
            opacity = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension View {
    func brewScreenBackground() -> some View {
        background(BrewTheme.Color.background.ignoresSafeArea())
    }
}
