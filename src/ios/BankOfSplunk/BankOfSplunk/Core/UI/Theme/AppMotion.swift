import SwiftUI

enum AppMotion {
    static let short = 0.2
    static let medium = 0.35
    static let long = 0.5

    static let standardSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)
    static let emphasisSpring = Animation.spring(response: 0.35, dampingFraction: 0.72)
    static let decelerate = Animation.easeOut(duration: medium)
}

struct M3ErrorTransition: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : -4)
            .animation(AppMotion.standardSpring, value: isVisible)
    }
}

struct M3PressScale: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(AppMotion.emphasisSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

extension View {
    func m3ErrorTransition(isVisible: Bool) -> some View {
        modifier(M3ErrorTransition(isVisible: isVisible))
    }

    func m3PressScale() -> some View {
        modifier(M3PressScale())
    }
}
