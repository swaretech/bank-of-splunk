import Foundation
import os.log

enum AppConfig {
    private static let logger = Logger(subsystem: "com.splunk.bankofsplunk", category: "RUM")
    static var apiBaseURL: URL {
        guard let url = URL(string: string(for: Keys.apiBaseURL)) else {
            fatalError("Invalid API_BASE_URL in xcconfig")
        }
        return url
    }

    /// Splunk `EndpointConfiguration.realm`
    static var realm: String { string(for: Keys.realm) }

    /// Splunk `EndpointConfiguration.rumAccessToken`
    static var rumAccessToken: String { string(for: Keys.rumAccessToken) }

    /// Splunk `AgentConfiguration.appName`
    static var appName: String { string(for: Keys.appName) }

    /// Splunk `AgentConfiguration.deploymentEnvironment`
    static var deploymentEnvironment: String { string(for: Keys.deploymentEnvironment) }

    /// Splunk `AgentConfiguration.appVersion` (defaults to CFBundleShortVersionString when unset).
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static var rumEnabled: Bool {
        rumDisabledReason == nil
    }

    /// True when built with RUM_LOADGEN=1 (loadgen / synthetic replay builds).
    static var rumLoadgenEnabled: Bool {
        let value = string(for: Keys.rumLoadgenEnabled).trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "1" || value.lowercased() == "true" || value.lowercased() == "yes"
    }

    /// Human-readable reason RUM is disabled at startup (DEBUG diagnostics).
    static var rumDisabledReason: String? {
        let token = rumAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty || token == "not-found" {
            return "Splunk RUM access token is missing from Info.plist. Copy Config/Secrets.xcconfig.example to Config/Secrets.xcconfig, set SPLUNK_RUM_ACCESS_TOKEN, then clean build."
        }
        if token == "disabled" {
            return "Splunk RUM access token is set to disabled in Secrets.xcconfig."
        }
        if realm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Splunk RUM realm is missing from Info.plist (SPLUNK_RUM_REALM)."
        }
        if appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Splunk RUM app name is missing from Info.plist (SPLUNK_RUM_APP_NAME)."
        }
        if deploymentEnvironment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Splunk RUM deployment environment is missing from Info.plist (SPLUNK_RUM_DEPLOYMENT_ENVIRONMENT)."
        }
        return nil
    }

    static func logRumConfiguration() {
        guard rumEnabled else {
            logger.notice("Splunk RUM disabled: \(rumDisabledReason ?? "unknown", privacy: .public)")
            return
        }

        logger.notice(
            """
            Splunk RUM config loaded: realm=\(realm, privacy: .public), \
            app=\(appName, privacy: .public), env=\(deploymentEnvironment, privacy: .public), \
            version=\(appVersion, privacy: .public), token=\(redactedToken, privacy: .public)
            """
        )
    }

    private static var redactedToken: String {
        let token = rumAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.count > 8 else { return "***" }
        return "\(token.prefix(4))…\(token.suffix(4))"
    }

    private enum Keys {
        static let apiBaseURL = "API_BASE_URL"
        static let realm = "SplunkRumRealm"
        static let rumAccessToken = "SplunkRumAccessToken"
        static let appName = "SplunkRumAppName"
        static let deploymentEnvironment = "SplunkRumDeploymentEnvironment"
        static let rumLoadgenEnabled = "RumLoadgenEnabled"
    }

    private static let legacyKeys: [String: [String]] = [
        Keys.realm: ["RUM_REALM", "SPLUNK_RUM_REALM"],
        Keys.rumAccessToken: ["RUM_ACCESS_TOKEN", "SPLUNK_RUM_ACCESS_TOKEN"],
        Keys.appName: ["RUM_APP_NAME", "SPLUNK_RUM_APP_NAME"],
        Keys.deploymentEnvironment: ["RUM_ENVIRONMENT", "SPLUNK_RUM_DEPLOYMENT_ENVIRONMENT"],
    ]

    private static func string(for key: String) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !value.isEmpty,
           !value.hasPrefix("$(") {
            return value
        }

        for legacyKey in legacyKeys[key] ?? [] {
            if let value = Bundle.main.object(forInfoDictionaryKey: legacyKey) as? String,
               !value.isEmpty,
               !value.hasPrefix("$(") {
                return value
            }
        }

        return ""
    }
}
