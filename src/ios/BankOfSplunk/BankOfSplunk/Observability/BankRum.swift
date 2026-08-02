import Foundation

#if canImport(SplunkAgent)
import OpenTelemetryApi
import SplunkAgent
#endif

enum BankRum {
    private static let blockedKeys = try! NSRegularExpression(
        pattern: "^(user|email|account|password|token|session)",
        options: [.caseInsensitive]
    )

    private static let sensitiveSpanKeys = try! NSRegularExpression(
        pattern: "(authorization|password|token|cookie|set-cookie)",
        options: [.caseInsensitive]
    )

    static var isEnabled: Bool {
        #if canImport(SplunkAgent)
        return AppConfig.rumEnabled
        #else
        return false
        #endif
    }

    static func dxaAttributes(
        trackId: String,
        component: String,
        flow: String? = nil
    ) -> [String: String] {
        var attrs = [
            "track.id": trackId,
            "component": component,
        ]
        if let flow {
            attrs["flow"] = flow
        }
        return attrs
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

    static func reportInteraction(
        trackId: String,
        component: String,
        flow: String? = nil
    ) {
        reportEvent("ui.interaction", attributes: dxaAttributes(
            trackId: trackId,
            component: component,
            flow: flow
        ))
    }

    static func reportValidationFailed(
        trackId: String,
        field: String?,
        component: String? = nil,
        flow: String? = nil
    ) {
        var attrs = dxaAttributes(trackId: trackId, component: component ?? DXA.pageComponent, flow: flow)
        if let field {
            attrs["field"] = field
        }
        reportEvent("form.validation_failed", attributes: attrs)
    }

    static func reportSubmitStarted(
        trackId: String,
        component: String? = nil,
        flow: String? = nil
    ) {
        reportEvent("form.submit_started", attributes: dxaAttributes(
            trackId: trackId,
            component: component ?? DXA.pageComponent,
            flow: flow
        ))
    }

    static func reportScreenOpened(_ screen: String) {
        reportEvent("ui.screen_opened", attributes: ["screen": screen])
    }

    static func reportLoginFailed() {
        reportEvent("auth.login_failed", attributes: dxaAttributes(
            trackId: DXA.loginSubmit,
            component: DXA.authFormComponent,
            flow: DXA.authenticationFlow
        ))
    }

    static func reportAPIError(operation: String, error: Error) {
        guard isEnabled else { return }
        #if canImport(SplunkAgent)
        var attrs = MutableAttributes()
        attrs["operation"] = .string(operation)
        attrs["event.name"] = .string("api.error")
        SplunkRum.shared.customTracking.trackError(
            "API error: \(operation)",
            attrs
        )
        #endif
    }

    static func trackScreen(_ screen: String, component: String = DXA.pageComponent, flow: String? = nil) {
        guard isEnabled else { return }
        #if canImport(SplunkAgent)
        SplunkRum.shared.navigation.track(screen: screen)
        reportEvent("ui.screen_view", attributes: dxaAttributes(
            trackId: screen,
            component: component,
            flow: flow
        ))
        #endif
    }

    #if canImport(SplunkAgent)
    static func redactSpanAttributes(_ attributes: [String: AttributeValue]) -> [String: AttributeValue] {
        var sanitized = attributes
        for key in attributes.keys {
            let range = NSRange(key.startIndex..<key.endIndex, in: key)
            if sensitiveSpanKeys.firstMatch(in: key, options: [], range: range) != nil {
                sanitized[key] = .string("redacted")
            }
            if key == "url.full" || key == "http.url", case .string(let url) = attributes[key] {
                sanitized[key] = .string(redactURL(url))
            }
        }
        return sanitized
    }
    #endif

    private static func redactURL(_ url: String) -> String {
        guard var components = URLComponents(string: url) else { return "redacted" }
        components.query = nil
        components.user = nil
        components.password = nil
        return components.string ?? "redacted"
    }

    private static func sanitize(_ attributes: [String: String]) -> [String: String] {
        attributes.filter { key, _ in
            let range = NSRange(key.startIndex..<key.endIndex, in: key)
            return blockedKeys.firstMatch(in: key, options: [], range: range) == nil
        }
    }
}
