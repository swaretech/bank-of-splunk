import Foundation

#if canImport(SplunkAgent)
import SplunkAgent
#endif

enum BankRum {
    private static let blockedKeys = try! NSRegularExpression(
        pattern: "^(user|email|account|password|token|session)",
        options: [.caseInsensitive]
    )

    static var isEnabled: Bool {
        #if canImport(SplunkAgent)
        return AppConfig.rumEnabled
        #else
        return false
        #endif
    }

    static func reportEvent(_ eventName: String, attributes: [String: String] = [:]) {
        guard isEnabled else { return }
        let payload = sanitize(attributes)
        #if canImport(SplunkAgent)
        var mutable = MutableAttributes()
        payload.forEach { key, value in
            mutable[key] = .string(value)
        }
        mutable["event.name"] = .string(eventName)
        SplunkRum.shared.customTracking.trackCustomEvent(eventName, mutable)
        #endif
    }

    static func reportValidationFailed(trackId: String, field: String?) {
        var attrs = ["track.id": trackId]
        if let field {
            attrs["field"] = field
        }
        reportEvent("form.validation_failed", attributes: attrs)
    }

    static func reportSubmitStarted(trackId: String) {
        reportEvent("form.submit_started", attributes: ["track.id": trackId])
    }

    static func reportScreenOpened(_ screen: String) {
        reportEvent("ui.screen_opened", attributes: ["screen": screen])
    }

    static func reportLoginFailed() {
        reportEvent("auth.login_failed")
    }

    static func trackScreen(_ screen: String, component: String = DXA.pageComponent, flow: String? = nil) {
        guard isEnabled else { return }
        #if canImport(SplunkAgent)
        SplunkRum.shared.navigation.track(screen: screen)
        var attrs = [
            "track.id": screen,
            "component": component,
        ]
        if let flow {
            attrs["flow"] = flow
        }
        reportEvent("ui.screen_view", attributes: attrs)
        #endif
    }

    private static func sanitize(_ attributes: [String: String]) -> [String: String] {
        attributes.filter { key, _ in
            let range = NSRange(key.startIndex..<key.endIndex, in: key)
            return blockedKeys.firstMatch(in: key, options: [], range: range) == nil
        }
    }
}
