import Foundation

#if canImport(SplunkAgent)
import SplunkAgent
#endif

enum SplunkRUMConfiguration {
    static func install() {
        guard AppConfig.rumEnabled else { return }

        #if canImport(SplunkAgent)
        let endpoint = EndpointConfiguration(
            realm: AppConfig.rumRealm,
            rumAccessToken: AppConfig.rumAccessToken
        )

        let agentConfiguration = AgentConfiguration(
            endpoint: endpoint,
            appName: AppConfig.rumAppName,
            deploymentEnvironment: AppConfig.rumEnvironment
        )
        .globalAttributes(MutableAttributes(dictionary: [
            "platform": .string("ios"),
            "app.channel": .string("mobile"),
        ]))
        .spanInterceptor { incoming in
            var spanData = incoming
            var attributes = spanData.attributes
            if let urlValue = attributes["url.full"], case .string(let url) = urlValue {
                attributes["url.full"] = .string(redactURL(url))
            }
            if let urlValue = attributes["http.url"], case .string(let url) = urlValue {
                attributes["http.url"] = .string(redactURL(url))
            }
            return spanData.settingAttributes(attributes)
        }

        do {
            let agent = try SplunkRum.install(with: agentConfiguration)
            agent.navigation.preferences.enableAutomatedTracking = true
            agent.sessionReplay.start()
        } catch {
            print("Unable to start Splunk RUM agent: \(error)")
        }
        #endif
    }

    private static func redactURL(_ url: String) -> String {
        guard var components = URLComponents(string: url) else { return "redacted" }
        components.query = nil
        return components.string ?? "redacted"
    }
}
