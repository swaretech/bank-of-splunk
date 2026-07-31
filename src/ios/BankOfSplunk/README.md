# Bank of Splunk — iOS App

Native SwiftUI iOS client for Bank of Splunk with **Splunk RUM for Mobile** and **DXA-compatible** instrumentation.

## Requirements

- Xcode 15+ (iOS 16 deployment target)
- Running Bank of Splunk backend (see root [README](/README.md))
- Splunk Observability Cloud RUM access token (optional; set `disabled` to run without telemetry)

## Setup

1. Copy the secrets template:

   ```sh
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

2. Edit `Config/Secrets.xcconfig`:

   | Key | Description |
   |-----|-------------|
   | `API_BASE_URL` | Frontend base URL (e.g. `http://127.0.0.1:8083` with port-forward) |
   | `RUM_REALM` | Splunk realm (e.g. `us0`) |
   | `RUM_ACCESS_TOKEN` | RUM token from Observability Cloud, or `disabled` |
   | `RUM_APP_NAME` | `bank-of-splunk-ios` |
   | `RUM_ENVIRONMENT` | e.g. `bank-local` |

3. Port-forward the frontend service:

   ```sh
   kubectl port-forward svc/frontend 8083:8083
   ```

4. Open `BankOfSplunk.xcodeproj` in Xcode and run on the Simulator.

## Architecture

The app calls JSON endpoints on the Flask frontend (`/api/v1/*`), which proxies to the same microservices as the web UI:

| Screen | API |
|--------|-----|
| Login | `POST /api/v1/login` |
| Signup | `POST /api/v1/signup` |
| Home | `GET /api/v1/home` |
| Deposit | `POST /api/v1/deposit` |
| Payment | `POST /api/v1/payment` |
| Logout | `POST /api/v1/logout` |

JWT is stored in the iOS Keychain and sent as `Authorization: Bearer`.

## Splunk RUM

- **SDK**: [SplunkAgent 2.0.6](https://github.com/signalfx/splunk-otel-ios) via Swift Package Manager
- **Init**: [`BankOfSplunk/Observability/SplunkRUMConfiguration.swift`](BankOfSplunk/Observability/SplunkRUMConfiguration.swift)
- **Modules**: automated navigation, URLSession network instrumentation, session replay, crash reporting
- **User tracking**: anonymous (DXA default)

## DXA instrumentation

Mobile DXA uses the same low-cardinality taxonomy as the web app. See [`BankOfSplunk/Observability/DXAIdentifiers.swift`](BankOfSplunk/Observability/DXAIdentifiers.swift).

| Web attribute | iOS equivalent |
|---------------|----------------|
| `data-trackid` | `accessibilityIdentifier` + `track.id` on custom events |
| `data-component` | `component` on custom events |
| `data-flow` | `flow` on custom events |

### Custom events (`BankRum.swift`)

| Event | When |
|-------|------|
| `form.validation_failed` | Client validation failure |
| `form.submit_started` | Before API submit |
| `auth.login_failed` | Login API failure |
| `ui.screen_opened` | Deposit/payment screen opened |
| `ui.screen_view` | Screen appear with DXA attrs |

### Recommended DXA event definitions

Create in Observability Cloud → Digital Experience Analytics → Event Definitions:

| Event | Filter |
|-------|--------|
| Login submitted | interaction / custom + `track.id=login-submit` |
| Deposit completed (intent) | `track.id=deposit-submit` |
| Payment completed (intent) | `track.id=payment-submit` |
| Registration started | `track.id=signup-navigate` |
| Auth failure | custom event `auth.login_failed` |
| Form validation issue | custom event `form.validation_failed` |

### Source mapping (optional)

```sh
splunk-rum upload-sourcemaps --platform ios --path .
```

Requires `SPLUNK_ACCESS_TOKEN` and realm env vars for DXA element picker resolution.

## Regenerating the Xcode project

If you add Swift files, run:

```sh
python3 generate_xcodeproj.py
```

## Verification

1. App logs in and shows balance + transactions
2. Deposit and Payment use **full screens** (not modals)
3. RUM Mobile dashboard shows sessions and `/api/v1/*` HTTP spans
4. Custom events appear for login failure and form validation
5. DXA lists `bank-of-splunk-ios` under Available applications
