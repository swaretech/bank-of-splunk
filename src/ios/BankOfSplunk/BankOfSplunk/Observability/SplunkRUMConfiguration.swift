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
        .userConfiguration(UserConfiguration(trackingMode: .anonymousTracking))
        .globalAttributes(MutableAttributes(dictionary: [
            "platform": .string("ios"),
            "app.channel": .string("mobile"),
        ]))
        .spanInterceptor { incoming in
            var spanData = incoming
            spanData = spanData.settingAttributes(
                BankRum.redactSpanAttributes(spanData.attributes)
            )
            return spanData
        }

        do {
            let agent = try SplunkRum.install(with: agentConfiguration)
            // SwiftUI app: manual screen names only (avoid UIHostingController noise).
            agent.navigation.preferences.enableAutomatedTracking = false
            configureSessionReplay(agent)
        } catch {
            print("Unable to start Splunk RUM agent: \(error)")
        }
        #endif
    }

    #if canImport(SplunkAgent)
    private static func configureSessionReplay(_ agent: SplunkRum) {
        guard AppConfig.rumEnvironment != "bank-local" else { return }

        agent.sessionReplay.preferences.renderingMode = .native
        agent.sessionReplay.start()
    }
    #endif
}
