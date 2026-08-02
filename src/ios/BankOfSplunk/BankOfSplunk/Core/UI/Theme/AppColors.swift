import SwiftUI

enum AppColors {
    // MARK: - Primary (deep purple M3)

    static let primary = Color("AccentColor")
    static let onPrimary = Color.white
    static let primaryContainer = Color.adaptive(
        light: Color(red: 0.92, green: 0.87, blue: 1.0),
        dark: Color(red: 0.31, green: 0.22, blue: 0.55)
    )
    static let onPrimaryContainer = Color.adaptive(
        light: Color(red: 0.13, green: 0.0, blue: 0.36),
        dark: Color(red: 0.92, green: 0.87, blue: 1.0)
    )

    // MARK: - Surface

    static let surface = Color.adaptive(
        light: Color(red: 0.99, green: 0.98, blue: 1.0),
        dark: Color(red: 0.07, green: 0.06, blue: 0.09)
    )
    static let surfaceContainer = Color.adaptive(
        light: Color(red: 0.95, green: 0.93, blue: 0.98),
        dark: Color(red: 0.14, green: 0.12, blue: 0.17)
    )
    static let surfaceContainerHigh = Color.adaptive(
        light: Color(red: 0.91, green: 0.88, blue: 0.95),
        dark: Color(red: 0.18, green: 0.16, blue: 0.21)
    )
    static let onSurface = Color.adaptive(
        light: Color(red: 0.11, green: 0.09, blue: 0.14),
        dark: Color(red: 0.91, green: 0.88, blue: 0.95)
    )
    static let onSurfaceVariant = Color.adaptive(
        light: Color(red: 0.29, green: 0.27, blue: 0.34),
        dark: Color(red: 0.78, green: 0.75, blue: 0.83)
    )
    static let outline = Color.adaptive(
        light: Color(red: 0.49, green: 0.46, blue: 0.56),
        dark: Color(red: 0.58, green: 0.55, blue: 0.65)
    )
    static let outlineVariant = Color.adaptive(
        light: Color(red: 0.78, green: 0.75, blue: 0.83),
        dark: Color(red: 0.29, green: 0.27, blue: 0.34)
    )

    // MARK: - Semantic

    static let error = Color.adaptive(
        light: Color(red: 0.73, green: 0.10, blue: 0.10),
        dark: Color(red: 0.96, green: 0.76, blue: 0.76)
    )
    static let onError = Color.white
    static let errorContainer = Color.adaptive(
        light: Color(red: 1.0, green: 0.90, blue: 0.90),
        dark: Color(red: 0.45, green: 0.07, blue: 0.07)
    )
    static let success = Color.adaptive(
        light: Color(red: 0.0, green: 0.47, blue: 0.24),
        dark: Color(red: 0.69, green: 0.91, blue: 0.76)
    )
    static let successContainer = Color.adaptive(
        light: Color(red: 0.88, green: 0.96, blue: 0.90),
        dark: Color(red: 0.0, green: 0.27, blue: 0.14)
    )
    static let credit = success
}

private extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
