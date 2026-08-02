# Bank of Splunk — iOS App

Native SwiftUI iOS client for Bank of Splunk with **Splunk RUM for Mobile** and **DXA-compatible** instrumentation.

## Requirements

- [Docker Desktop](https://www.docker.com/) (running)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [`k3d`](https://k3d.io) — `brew install k3d`
- [`skaffold`](https://skaffold.dev/docs/install/) 2.9+
- OpenJDK 21+ and Maven (for Java microservices in Option B deploy)
- Xcode 15+ (iOS 16 deployment target)
- Splunk Observability Cloud RUM access token (optional; set `disabled` to run without telemetry)

## Local end-to-end run

These steps start the Kubernetes backend from source, expose the mobile JSON API, and run the app in the iOS Simulator.

### 1. Start the backend (first time)

From the **repository root** (not this directory):

```sh
# Create a local cluster (once)
k3d cluster create bank-of-splunk

# Build images, load into k3d, and deploy all services
./extras/local-k8s/deploy-option-b.sh
```

This uses Docker to build application images and Skaffold for the databases. Expect several minutes on first run. When finished, all pods should be `Running`:

```sh
kubectl --context k3d-bank-of-splunk get pods
```

Re-deploy after code changes without rebuilding everything:

```sh
SKIP_BUILD=true ./extras/local-k8s/deploy-option-b.sh
```

Rebuild only the frontend after mobile API changes:

```sh
docker build -t bank-of-splunk/frontend:local src/frontend
k3d image import bank-of-splunk/frontend:local -c bank-of-splunk
kubectl --context k3d-bank-of-splunk rollout restart deployment/frontend
```

See the root [README](/README.md) Quickstart for Option A (pre-built GHCR images), Apple Silicon notes, and tear-down (`k3d cluster delete bank-of-splunk`).

### 2. Port-forward the frontend

In a **separate terminal**, keep this running while you use the app:

```sh
kubectl --context k3d-bank-of-splunk port-forward service/frontend 8083:8083
```

Verify the mobile login API from your Mac:

```sh
curl -s -X POST http://127.0.0.1:8083/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"testuser","password":"bankofsplunk"}'
```

You should get JSON with a `token` field.

### 3. Configure the iOS app

```sh
cd src/ios/BankOfSplunk
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Default `API_BASE_URL` is `http://127.0.0.1:8083`, which matches the port-forward above. All Splunk RUM settings (`RUM_REALM`, `RUM_ACCESS_TOKEN`, `RUM_APP_NAME`, `RUM_ENVIRONMENT`) are read from `Secrets.xcconfig` only — set `RUM_ACCESS_TOKEN = disabled` there to run without telemetry.

### 4. Build and run

**Xcode:** open `BankOfSplunk.xcodeproj`, select an iPhone Simulator, press **⌘R**.

**Command line:**

```sh
cd src/ios/BankOfSplunk
xcodebuild -scheme BankOfSplunk -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
open BankOfSplunk.xcodeproj
```

Debug builds pre-fill `testuser` / `bankofsplunk` and show the API URL on the login screen.

## Setup (reference)

If the backend is already running, you only need steps 3–4 in **Local end-to-end run** above.

1. Copy the secrets template (if you have not already):

   ```sh
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

2. Edit `Config/Secrets.xcconfig` (sole source for RUM credentials):

   | Key | Description |
   |-----|-------------|
   | `RUM_REALM` | Splunk realm (e.g. `us0`, `us1`) |
   | `RUM_ACCESS_TOKEN` | RUM token from Observability Cloud, or `disabled` |
   | `RUM_APP_NAME` | `bank-of-splunk-ios` |
   | `RUM_ENVIRONMENT` | e.g. `bank-local` |

   `Debug.xcconfig` / `Release.xcconfig` only override `API_BASE_URL` per build flavor (local vs production). After changing secrets, clean build in Xcode (**Product → Clean Build Folder**) so `Info.plist` picks up new values.

## Demo credentials

When the backend is deployed with demo data (`USE_DEMO_DATA=True` in [`kubernetes-manifests/config.yaml`](/kubernetes-manifests/config.yaml)), these pre-seeded accounts work for login:

| Username | Password |
|----------|----------|
| `testuser` | `bankofsplunk` |
| `alice` | `bankofsplunk` |
| `bob` | `bankofsplunk` |

All demo users share the same password. See [`src/accounts/accounts-db/initdb/1-load-testdata.sql`](/src/accounts/accounts-db/initdb/1-load-testdata.sql) for the full seed set (`eve` is also available).

## Troubleshooting login

If sign-in fails, the login screen (Debug builds) shows the configured API URL at the bottom. Common causes:

1. **Port-forward not running or wrong port** — the app expects `http://127.0.0.1:8083`. Run exactly:
   ```sh
   kubectl --context k3d-bank-of-splunk port-forward service/frontend 8083:8083
   ```
   If you use a different local port (e.g. `8084:8083`), update `API_BASE_URL` in `Config/Secrets.xcconfig` to match.

2. **Frontend image missing `/api/v1`** — rebuild and redeploy the frontend after pulling the iOS/mobile API changes:
   ```sh
   extras/local-k8s/deploy-option-b.sh
   ```

3. **Verify the API from your Mac** (should return JSON with a token):
   ```sh
   curl -s -X POST http://127.0.0.1:8083/api/v1/login \
     -H 'Content-Type: application/json' \
     -d '{"username":"testuser","password":"bankofsplunk"}'
   ```
   A `401` here means bad credentials; connection refused means port-forward is down; `404` means the frontend needs redeploying.

4. **Physical device** — `127.0.0.1` points at the phone, not your Mac. Set `API_BASE_URL` to your Mac's LAN IP (e.g. `http://192.168.1.10:8083`) and port-forward as above.

5. **Simulator keyboard not visible** — if the field highlights but no on-screen keyboard appears, the Simulator may be using your Mac keyboard. Toggle **I/O → Keyboard → Toggle Software Keyboard** (or press **⌘K**). Uncheck **I/O → Keyboard → Connect Hardware Keyboard** for local testing.

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

- **SDK**: [SplunkAgent 2.2.3](https://github.com/signalfx/splunk-otel-ios) via Swift Package Manager
- **Init**: [`BankOfSplunk/Observability/SplunkRUMConfiguration.swift`](BankOfSplunk/Observability/SplunkRUMConfiguration.swift)
- **Modules**: URLSession network instrumentation, session replay, crash reporting
- **User tracking**: anonymous (`UserTrackingMode.anonymousTracking`)
- **Navigation**: UIKit automated navigation is **disabled** (SwiftUI screens use explicit `ui.screen_view` / `ui.interaction` events instead)
- **Privacy**: span interceptor redacts `Authorization` headers, request/response bodies, and query strings on HTTP spans; session replay uses `SplunkRum.shared.sessionReplay.sensitivity` (via `.dxaSensitiveContent()` and `.dxaSensitiveFormSection()`) on all input fields, balances, PII, contact pickers, banners, and error messages

### Session Replay privacy verification

After deploying with RUM enabled, verify in Observability Cloud:

1. Record a session through Login → Home → Deposit with typed values.
2. Confirm input areas show masked/blurred blocks during typing (keystrokes and values not visible).
3. Confirm contact picker labels, balance, banner text, and transaction amounts are masked in replay.
4. Open session details / custom events — confirm no username, account number, amount, or password values appear in attribute headers.

Custom event and span attribute keys matching `user`, `email`, `account`, `password`, `token`, `session`, `routing`, `balance`, `amount`, `label`, `name`, `birthday`, `username`, `credential`, or `value` are stripped before export (aligned with the web app's `onAttributesSerializing` filter).

## Design system

The app uses a **Material 3-inspired** SwiftUI design system with deep purple (`#4F378B`) as the primary brand color.

| Layer | Location |
|-------|----------|
| Color, typography, shape, motion tokens | [`BankOfSplunk/Core/UI/Theme/`](BankOfSplunk/Core/UI/Theme/) |
| Reusable M3 components (buttons, fields, cards, banner, transaction rows) | [`BankOfSplunk/Core/UI/Components/`](BankOfSplunk/Core/UI/Components/) |
| Accent color asset | [`BankOfSplunk/Resources/Assets.xcassets/AccentColor.colorset`](BankOfSplunk/Resources/Assets.xcassets/AccentColor.colorset/) |

All six screens (Login, Signup, Home, Deposit, Payment, Transactions) use the shared components with M3 surface containers, filled/outlined buttons, spring animations, and adaptive light/dark palettes.

## DXA instrumentation

Mobile DXA uses the same low-cardinality taxonomy as the web app. See [`BankOfSplunk/Observability/DXAIdentifiers.swift`](BankOfSplunk/Observability/DXAIdentifiers.swift) and helpers in [`BankOfSplunk/Core/UI/DXAViewModifiers.swift`](BankOfSplunk/Core/UI/DXAViewModifiers.swift).

| Web attribute | iOS equivalent |
|---------------|----------------|
| `data-trackid` | `accessibilityIdentifier` via `.dxaTrackID(...)` + `track.id` on custom events |
| `data-component` | `component` on custom events (via `BankRum.dxaAttributes`) |
| `data-flow` | `flow` on custom events (via `BankRum.dxaAttributes`) |
| Sensitive content | `.dxaSensitiveContent()` / `.dxaSensitiveFormSection()` → Splunk RUM session replay sensitivity masking |

### Custom events (`BankRum.swift`)

| Event | When |
|-------|------|
| `form.validation_failed` | Client validation failure (`component`, `flow`, `track.id`) |
| `form.submit_started` | Before API submit |
| `auth.login_failed` | Login API failure |
| `ui.screen_opened` | Deposit/payment screen opened |
| `ui.screen_view` | Screen appear with DXA attrs |
| `ui.interaction` | Explicit nav/submit taps (e.g. transactions, deposit, payment) |
| `api.error` | Non-auth API failures (network/5xx) with `endpoint` + `status` |

### Recommended DXA event definitions

Create in Observability Cloud → Digital Experience Analytics → Event Definitions:

| Event | Filter |
|-------|--------|
| Login submitted | custom + `track.id=login-submit` or interaction + `track.id=login-submit` |
| Deposit completed (intent) | `track.id=deposit-submit` |
| Payment completed (intent) | `track.id=payment-submit` |
| Registration started | `track.id=signup-navigate` |
| View transactions | `track.id=transactions-open` |
| Auth failure | custom event `auth.login_failed` |
| Form validation issue | custom event `form.validation_failed` |
| API error | custom event `api.error` |

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
