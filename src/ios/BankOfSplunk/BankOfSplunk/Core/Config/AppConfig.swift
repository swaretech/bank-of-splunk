import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        guard let url = URL(string: string(for: "API_BASE_URL")) else {
            fatalError("Invalid API_BASE_URL in xcconfig")
        }
        return url
    }

    static var rumRealm: String { string(for: "RUM_REALM") }
    static var rumAccessToken: String { string(for: "RUM_ACCESS_TOKEN") }
    static var rumAppName: String { string(for: "RUM_APP_NAME") }
    static var rumEnvironment: String { string(for: "RUM_ENVIRONMENT") }
    static var splunkVersion: String { string(for: "SPLUNK_VERSION") }

    static var rumEnabled: Bool {
        let token = rumAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return !token.isEmpty && token != "disabled" && token != "not-found"
    }

    private static func string(for key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? ""
    }
}
