import SwiftUI

public extension Color {
    /// Price going up.
    static let pulseUp = Color(red: 0.16, green: 0.78, blue: 0.47)
    /// Price going down.
    static let pulseDown = Color(red: 0.96, green: 0.30, blue: 0.33)
    /// Brand violet, also the app's accent color.
    static let pulseAccent = Color(red: 0.49, green: 0.36, blue: 1.0)

    /// Distinct colors for chart series (allocation slices), in order.
    static let pulseChartPalette: [Color] = [
        .pulseAccent,
        Color(red: 0.16, green: 0.78, blue: 0.67),
        Color(red: 1.0, green: 0.62, blue: 0.20),
        Color(red: 0.25, green: 0.56, blue: 1.0),
        Color(red: 0.95, green: 0.36, blue: 0.62),
        Color(red: 0.62, green: 0.62, blue: 0.66),
    ]

    /// Green, red or gray for a percent change.
    static func trend(_ change: Double?) -> Color {
        guard let change, change != 0 else { return .secondary }
        return change > 0 ? .pulseUp : .pulseDown
    }
}

public extension Font {
    /// Rounded, tabular digits so prices don't jiggle when they update.
    static func pulseNumber(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }
}
