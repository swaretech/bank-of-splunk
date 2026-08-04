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

These steps start the Kubernetes backend from source, expose the mobile JSON API, and run the app in the iOS Simulator. Paths like `src/ios/...` and `./extras/...` are relative to the **repository root** (`bank-of-splunk/`). If your shell is already in this folder (`src/ios/BankOfSplunk/`), run `cd ../..` before step 1.

### 1. Start the backend

From the **repository root**:

**First time** — create the cluster and deploy:

```sh
# Create a local cluster (once; skip if k3d cluster list already shows bank-of-splunk)
k3d cluster create bank-of-splunk

# Build images, load into k3d, and deploy all services (several minutes on first run)
./extras/local-k8s/deploy-option-b.sh
```

This builds application images with Docker and databases with Skaffold, then loads everything into k3d.

**Already deployed** — after restarting Docker Desktop or the k3d containers (Docker Desktop UI **Restart** on `k3d-bank-of-splunk-*` containers, or from the CLI):

```sh
# Bring the k3d cluster back up (safe if it is already running)
k3d cluster start bank-of-splunk

# Restart Bank of Splunk application pods
kubectl --context k3d-bank-of-splunk rollout restart deployment --all
kubectl --context k3d-bank-of-splunk get pods --watch
```

If pods stay unhealthy or the API still fails after a restart, redeploy without rebuilding images:

```sh
SKIP_BUILD=true ./extras/local-k8s/deploy-option-b.sh
```

When finished, all pods should be `Running`:

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

In a **separate terminal** (any directory — your cwd does not matter for `kubectl`), keep this running while you use the app:

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

Change to **`src/ios/BankOfSplunk/`**:

```sh
cd src/ios/BankOfSplunk   # skip if already here
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Default `API_BASE_URL` is `http://127.0.0.1:8083`, which matches the port-forward above. Splunk RUM settings are read from `Secrets.xcconfig` using keys that map to `AgentConfiguration` / `EndpointConfiguration` (`SPLUNK_RUM_REALM`, `SPLUNK_RUM_ACCESS_TOKEN`, `SPLUNK_RUM_APP_NAME`, `SPLUNK_RUM_DEPLOYMENT_ENVIRONMENT`). Set `SPLUNK_RUM_ACCESS_TOKEN = disabled` to run without telemetry. App version uses standard iOS `MARKETING_VERSION` → `CFBundleShortVersionString` → `appVersion`.

### 4. Build and run

**Xcode:** open `BankOfSplunk.xcodeproj`, select an iPhone Simulator, press **⌘R**.

**Command line:**

```sh
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

   | xcconfig key | Splunk `install()` parameter | RUM resource attribute | Description |
   |-----|-----|-----|-------------|
   | `SPLUNK_RUM_REALM` | `realm` | (ingest routing) | Splunk realm (e.g. `us0`, `us1`) |
   | `SPLUNK_RUM_ACCESS_TOKEN` | `rumAccessToken` | (ingest auth) | RUM token from Observability Cloud, or `disabled` |
   | `SPLUNK_RUM_APP_NAME` | `appName` | **`app`** | e.g. `bank-of-splunk-ios` — **UI filter uses `app`, not `app.name`** |
   | `SPLUNK_RUM_DEPLOYMENT_ENVIRONMENT` | `deploymentEnvironment` | **`deployment.environment`** | e.g. `bank-local` |
   | `MARKETING_VERSION` | `appVersion` | **`app.version`** | Set here or in Xcode → General → Version |

   Per the [iOS RUM data model](https://help.splunk.com/en/splunk-observability-cloud/manage-data/instrument-front-end-applications/instrument-mobile-and-web-applications-for-splunk-real-user-monitoring-rum/instrument-ios-applications-for-splunk-rum/splunk-rum-ios-agent-version-2.0.0-and-above/ios-rum-data-model), exported spans carry resource attributes `app`, `app.version`, and `deployment.environment`. There is no `app.name` resource attribute in the iOS agent.

   `Debug.xcconfig` / `Release.xcconfig` only override `API_BASE_URL` per build flavor (local vs production). They do **not** override `MARKETING_VERSION` or Splunk keys. After changing secrets, clean build in Xcode (**Product → Clean Build Folder**) so `Info.plist` picks up new values.

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

2. **Frontend image missing `/api/v1`** — from **repository root**, rebuild and redeploy the frontend after pulling the iOS/mobile API changes:
   ```sh
   ./extras/local-k8s/deploy-option-b.sh
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

Custom event attribute keys starting with `user`, `email`, `account`, `password`, `token`, `session`, `routing`, `balance`, `amount`, `label`, `name`, `birthday`, `username`, `credential`, or `value` are stripped before export. Span redaction preserves Splunk RUM system attributes such as **`session.id`** and **`screen.name`** (required for session grouping); only PII/secret keys like `http.request.body` and `authorization` are redacted.

### Troubleshooting: sessions not visible in Observability Cloud

1. **Clean rebuild after changing `Secrets.xcconfig`** — RUM credentials are baked into `Info.plist` at build time. After editing `SPLUNK_RUM_*` keys, run **Product → Clean Build Folder** and rebuild.
2. **Check Xcode console on launch (Debug builds)** — filter for subsystem `com.splunk.bankofsplunk`. You should see:
   - `Splunk RUM config loaded: realm=…, app=…, env=…`
   - `Splunk RUM agent started (v2.2.3).`
   If you see `Splunk RUM disabled: …`, fix the reason shown (missing token, `disabled`, or unresolved `$(SPLUNK_RUM_*)` placeholders).
3. **Filter the RUM UI correctly** — local builds use resource attributes (not `app.name`):
   - **`app`**: `bank-of-splunk-ios`
   - **`deployment.environment`**: `bank-local`
   - **Realm**: `us1` (must match `SPLUNK_RUM_REALM`)
4. **Confirm span resources in Xcode console** — after launch you should see `app=bank-of-splunk-ios`, `app.version=1.2.0` (or your `MARKETING_VERSION`), not `app.name`. If `app.version` still shows `1.0.0`, clean build — an old `Debug.xcconfig` override may be cached in a prior build.
5. **Use RUM for Mobile**, not Browser RUM — iOS sessions appear under Mobile instrumentation.
6. **Allow export time** — the SDK batches and uploads via background URLSession; background the app or wait ~30s after interacting, then refresh the dashboard (last 15 minutes).
7. **Verify ingest in Console (Debug builds)** — after launch, look for:
   - `RUM ingest probe: POST …/v1/traces → HTTP 200` (token accepted)
   - `HTTP 401` / `403` → token rejected; set `SPLUNK_RUM_ACCESS_TOKEN` to the same value as Kubernetes `workshop-secret` key `rum_token` / web `RUM_AUTH`
   - OpenTelemetry span output under `com.splunk.rum` confirms recording; CFNetwork `OTLPBackgroundExporter` upload tasks confirm export is queued
8. **Token must match web RUM** — iOS and browser RUM share the same RUM access token type. Copy from Observability Cloud → RUM setup, or from your cluster secret:
   ```sh
   kubectl get secret workshop-secret -o jsonpath='{.data.rum_token}' | base64 -d; echo
   ```
   Paste that value into `SPLUNK_RUM_ACCESS_TOKEN` in `Secrets.xcconfig`, then clean rebuild.

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

## iOS RUM load generator

Generate synthetic RUM mobile sessions by replaying YAML scenarios against the iOS Simulator on your Mac.

**Prerequisites:** k3d backend running (step 1), frontend port-forward on `:8083` (step 2), real `SPLUNK_RUM_ACCESS_TOKEN` in `src/ios/BankOfSplunk/Config/Secrets.xcconfig`.

```sh
# Terminal 1 — any directory; keep running
kubectl --context k3d-bank-of-splunk port-forward service/frontend 8083:8083

# Terminal 2 — change to src/ios/rum-loadgen/
cd src/ios/rum-loadgen
source .venv/bin/activate   # after one-time setup (see rum-loadgen README)
./scripts/run-all.sh
```

From **`src/ios/BankOfSplunk/`**, use `cd ../rum-loadgen` instead of the `cd` above.

Full setup, recording, scheduling, and troubleshooting: [`../rum-loadgen/README.md`](../rum-loadgen/README.md).

## Verification

1. App logs in and shows balance + transactions
2. Deposit and Payment use **full screens** (not modals)
3. RUM Mobile dashboard shows sessions and `/api/v1/*` HTTP spans
4. Custom events appear for login failure and form validation
5. DXA lists `bank-of-splunk-ios` under Available applications
