import Foundation

#if canImport(SplunkAgent)
import OpenTelemetryApi
import SplunkAgent
#endif

enum BankRum {
    /// Splunk RUM / DXA span attributes that must never be redacted (required for session grouping).
    private static let rumSystemSpanKeys: Set<String> = [
        "session.id",
        "screen.name",
        "component",
        "track.id",
        "event.name",
        "flow",
        "operation",
        "field",
        "platform",
        "app.channel",
        "screen",
    ]

    private static let blockedKeys = try! NSRegularExpression(
        pattern: "^(user|email|account|password|token|session|routing|balance|amount|label|name|birthday|firstname|lastname|username|credential|value)",
        options: [.caseInsensitive]
    )

    /// PII / secret span keys. Uses word boundaries so `session.id` is not matched by `session`.
    private static let sensitiveSpanKeys = try! NSRegularExpression(
        pattern: "\\b(authorization|password|token|cookie|set-cookie|username|account|routing|balance|amount|credential|email|firstname|lastname|birthday)\\b|http\\.request\\.body|http\\.response\\.body|request\\.body|response\\.body",
        options: [.caseInsensitive]
    )

    static var isEnabled: Bool {
        #if canImport(SplunkAgent)
        guard AppConfig.rumEnabled else { return false }
        if case .running = SplunkRum.shared.state.status {
            return true
        }
        return false
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
        // Only field names are emitted — never user-entered values.
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
            "API error during \(operation)",
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
            if rumSystemSpanKeys.contains(key) {
                continue
            }
            if key.hasPrefix("splunk.") || key.hasPrefix("otel.") {
                continue
            }
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
