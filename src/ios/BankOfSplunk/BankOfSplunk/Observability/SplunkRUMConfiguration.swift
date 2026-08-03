import Foundation
import os.log

#if canImport(SplunkAgent)
import SplunkAgent
#endif

enum SplunkRUMConfiguration {
    private static let logger = Logger(subsystem: "com.splunk.bankofsplunk", category: "RUM")
    private static var didInstall = false

    static func install() {
        guard !didInstall else { return }
        didInstall = true

        AppConfig.logRumConfiguration()
        guard AppConfig.rumEnabled else { return }

        logger.notice(
            """
            RUM ingest endpoints: traces=https://rum-ingest.\(AppConfig.realm, privacy: .public).observability.splunkcloud.com/v1/traces, \
            replay=https://rum-ingest.\(AppConfig.realm, privacy: .public).observability.splunkcloud.com/v1/logs
            """
        )

        #if canImport(SplunkAgent)
        var agentConfiguration = AgentConfiguration(
            endpoint: EndpointConfiguration(
                realm: AppConfig.realm,
                rumAccessToken: AppConfig.rumAccessToken
            ),
            appName: AppConfig.appName,
            deploymentEnvironment: AppConfig.deploymentEnvironment
        )
        .appVersion(AppConfig.appVersion)
        .userConfiguration(UserConfiguration(trackingMode: .anonymousTracking))
        .globalAttributes(globalAttributes())
        .sessionConfiguration(SessionConfiguration(samplingRate: 1.0))
        .spanInterceptor { incoming in
            var spanData = incoming
            spanData = spanData.settingAttributes(
                BankRum.redactSpanAttributes(spanData.attributes)
            )
            return spanData
        }

        #if DEBUG
        agentConfiguration = agentConfiguration.enableDebugLogging(true)
        #endif

        do {
            let agent = try SplunkRum.install(with: agentConfiguration)

            switch agent.state.status {
            case .running:
                logger.notice(
                    """
                    Splunk RUM agent started (v\(SplunkRum.version, privacy: .public)). \
                    Resources: app=\(agent.state.appName, privacy: .public), \
                    app.version=\(agent.state.appVersion, privacy: .public), \
                    deployment.environment=\(agent.state.deploymentEnvironment, privacy: .public)
                    """
                )
                agent.navigation.preferences.enableAutomatedTracking = false
                configureSessionReplay(agent)
                agent.customTracking.trackCustomEvent(
                    "rum.agent_started",
                    MutableAttributes(dictionary: [
                        "app": .string(agent.state.appName),
                        "app.version": .string(agent.state.appVersion),
                        "deployment.environment": .string(agent.state.deploymentEnvironment),
                    ])
                )
            case .notRunning(let cause):
                logger.error("Splunk RUM install returned non-running status: \(String(describing: cause), privacy: .public)")
            }
        } catch {
            logger.error("Unable to start Splunk RUM agent: \(String(describing: error), privacy: .public)")
        }

        #if DEBUG
        RumIngestProbe.verifyIngestReachable()
        #endif
        #else
        logger.error("SplunkAgent package is not linked; RUM instrumentation is unavailable.")
        #endif
    }

    #if canImport(SplunkAgent)
    private static func globalAttributes() -> MutableAttributes {
        var attributes = MutableAttributes()
        attributes["platform"] = .string("ios")
        attributes["app.channel"] = .string("mobile")
        if AppConfig.rumLoadgenEnabled {
            attributes["synthetic"] = .string("true")
            attributes["loadgen.source"] = .string("ios-rum-loadgen")
        }
        return attributes
    }

    private static func configureSessionReplay(_ agent: SplunkRum) {
        agent.sessionReplay.preferences.renderingMode = .native
        agent.sessionReplay.start()
        logger.notice("Splunk RUM session replay started.")
    }
    #endif
}
