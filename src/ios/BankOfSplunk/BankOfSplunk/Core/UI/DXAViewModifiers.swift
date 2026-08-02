import SwiftUI
import UIKit

#if canImport(SplunkAgent)
import SplunkAgent
#endif

extension View {
    /// Stable DXA element id (maps to web `data-trackid`).
    func dxaTrackID(_ trackId: String) -> some View {
        accessibilityIdentifier(trackId)
    }

    /// Hide sensitive content from Session Replay (maps to web replay masking).
    func dxaSensitiveContent() -> some View {
        modifier(SessionReplaySensitiveModifier())
    }

    /// Mark an entire form section (and all child inputs) as session-replay sensitive.
    func dxaSensitiveFormSection() -> some View {
        Group {
            self
        }
        .dxaSensitiveContent()
    }

    /// Emit a low-cardinality DXA interaction event with component and flow.
    func dxaInteraction(
        trackId: String,
        component: String,
        flow: String? = nil
    ) -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                BankRum.reportInteraction(trackId: trackId, component: component, flow: flow)
            }
        )
    }
}

private struct SessionReplaySensitiveModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(SplunkAgent)
        content.background(SessionReplaySensitiveMarker())
        #else
        content
        #endif
    }
}

#if canImport(SplunkAgent)
private struct SessionReplaySensitiveMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        SplunkRum.shared.sessionReplay.sensitivity[uiView] = true
    }
}
#endif
