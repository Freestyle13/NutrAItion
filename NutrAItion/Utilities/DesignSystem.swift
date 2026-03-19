import Foundation
import SwiftUI

// Centralized styling tokens for NutrAItion.
// Used by all views in Phase 7 for consistent dark-mode UI.

extension Color {
    // Backgrounds
    static let cardBackground = Color(hex: "#252545") // all cards + entries
    static let deepBackground = Color(hex: "#1A1A32") // tab bar, sheets
    static let ringTrack = Color(hex: "#2E2E58") // unfilled ring arc

    // Borders
    static let cardBorder = Color(hex: "#363660") // card stroke
    static let tabBorder = Color(hex: "#2E2E52") // tab bar top edge

    // Text
    static let textPrimary = Color.white
    static let textMuted = Color(hex: "#9898C0") // labels, secondary
    static let textDim = Color(hex: "#6868A0") // timestamps, subtext
    static let textGhost = Color(hex: "#484878") // inactive tab labels

    // Accent
    static let accentPurple = Color(hex: "#7B7BE8") // primary accent, rings

    // Macros
    static let macroProtein = Color(hex: "#3DDC84") // green
    static let macroCarbs = Color(hex: "#FF9500") // orange
    static let macroFat = Color(hex: "#FF6B9D") // pink

    // Effort levels
    static let effortRest = Color(hex: "#6868A0")
    static let effortLow = Color(hex: "#4A9EFF")
    static let effortModerate = Color(hex: "#3DDC84")
    static let effortHigh = Color(hex: "#FF9500")
    static let effortVeryHigh = Color(hex: "#FF4444")

    // Confidence badges
    static let badgeAI = Color(hex: "#FF9500") // .estimated
    static let badgeRecipe = Color(hex: "#4A9EFF") // .recipe

    // Icon tint backgrounds (for food entry icons)
    static let iconBgGreen = Color(hex: "#1E3828")
    static let iconBgPurple = Color(hex: "#261E38")
    static let iconBgOrange = Color(hex: "#38281A")
    static let iconBgBlue = Color(hex: "#081018")
}

extension Color {
    // Hex initializer to support design-token colors.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

extension CGFloat {
    // Shape tokens
    static let radiusCard: CGFloat = 18 // macro cards, entry rows
    static let radiusSmall: CGFloat = 10 // food entry icon background
    static let radiusBadge: CGFloat = 4 // AI est. / Recipe badges
    static let radiusPhone: CGFloat = 44 // not used in app, reference only

    // Spacing tokens
    static let cardPaddingH: CGFloat = 14
    static let cardPaddingV: CGFloat = 12
    static let screenPadding: CGFloat = 20 // left/right inset on all screens
    static let cardGap: CGFloat = 10 // gap between macro cards in row
    static let sectionGap: CGFloat = 20 // between dashboard sections
}

extension Font {
    static let screenTitle = Font.system(size: 24, weight: .bold)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let cardValue = Font.system(size: 13, weight: .semibold)
    static let cardLabel = Font.system(size: 10, weight: .regular)
    static let entryName = Font.system(size: 13, weight: .medium)
    static let entryMeta = Font.system(size: 11, weight: .regular)
    static let macroRingVal = Font.system(size: 11, weight: .bold)
    static let calRingVal = Font.system(size: 28, weight: .bold)
    static let calRingLabel = Font.system(size: 11, weight: .regular)
    static let badgeText = Font.system(size: 9, weight: .medium)
    static let greeting = Font.system(size: 13, weight: .regular)
}

/// Primary action button behavior for "accentPurple fill" buttons.
/// Scales slightly when pressed to feel responsive but not theatrical.
struct AccentPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

