import Foundation
import os.log

#if DEBUG
/// Verifies RUM ingest accepts the configured token (logs HTTP status only, never the token).
enum RumIngestProbe {
    private static let logger = Logger(subsystem: "com.splunk.bankofsplunk", category: "RUM")

    static func verifyIngestReachable() {
        guard AppConfig.rumEnabled else { return }

        let urlString = "https://rum-ingest.\(AppConfig.realm).observability.splunkcloud.com/v1/traces"
        guard let url = URL(string: urlString) else {
            logger.error("RUM ingest probe: invalid URL for realm \(AppConfig.realm, privacy: .public)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.rumAccessToken, forHTTPHeaderField: "X-SF-Token")
        request.httpBody = Data("{\"resourceSpans\":[]}".utf8)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                logger.error("RUM ingest probe network error: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let http = response as? HTTPURLResponse else {
                logger.error("RUM ingest probe: no HTTP response")
                return
            }
            logger.notice(
                "RUM ingest probe: POST \(urlString, privacy: .public) → HTTP \(http.statusCode, privacy: .public)"
            )
            switch http.statusCode {
            case 200 ... 299:
                logger.notice("RUM ingest probe: token accepted for realm \(AppConfig.realm, privacy: .public)")
            case 401, 403:
                logger.error(
                    """
                    RUM ingest probe: token rejected (HTTP \(http.statusCode)). \
                    Use the same RUM access token as web RUM_AUTH / workshop-secret rum_token.
                    """
                )
            default:
                logger.error("RUM ingest probe: unexpected HTTP \(http.statusCode, privacy: .public)")
            }
        }.resume()
    }
}
#endif
