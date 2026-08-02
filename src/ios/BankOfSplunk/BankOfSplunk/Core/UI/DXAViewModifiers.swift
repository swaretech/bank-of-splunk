import SwiftUI

#if canImport(CiscoSessionReplay)
import CiscoSessionReplay
#endif

extension View {
    /// Stable DXA element id (maps to web `data-trackid`).
    func dxaTrackID(_ trackId: String) -> some View {
        accessibilityIdentifier(trackId)
    }

    /// Hide sensitive content from Session Replay (maps to web replay masking).
    func dxaSensitiveContent() -> some View {
        #if canImport(CiscoSessionReplay)
        sessionReplaySensitive(true)
        #else
        self
        #endif
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
