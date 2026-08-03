# iOS RUM Load Generator

Record user scenarios on the Bank of Splunk iOS app with Appium Inspector, save them as structured YAML, and replay them on a schedule to generate real Splunk RUM mobile sessions.

Replay drives the actual app in the iOS Simulator. The Splunk RUM SDK exports OTLP traces and session replay to Observability Cloud — sessions are not injected via the ingest API.

## Prerequisites

- macOS with Xcode 15+ and an iOS Simulator (e.g. iPhone 17)
- Python 3.12+
- Node.js 20+ (for Appium)
- Appium 2.x with the XCUITest driver
- [Appium Inspector](https://github.com/appium/appium-inspector/releases) (for recording)
- Bank of Splunk backend reachable (local port-forward or deployed demo API)
- `Config/Secrets.xcconfig` with a real `SPLUNK_RUM_ACCESS_TOKEN` (not `disabled`)

### One-time setup

```sh
cd src/ios/rum-loadgen

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

npm install -g appium
appium driver install xcuitest
```

For local development, keep the backend API available:

```sh
kubectl --context k3d-bank-of-splunk port-forward service/frontend 8083:8083
```

## Directory layout

```
src/ios/rum-loadgen/
├── appium/capabilities.json   # XCUITest capabilities
├── scenarios/                 # Normalized YAML scenarios (committed)
├── recordings/raw/            # Raw Inspector exports (gitignored)
├── scripts/
│   ├── record.sh              # Start Appium + recording instructions
│   ├── normalize.py           # Inspector export → YAML
│   ├── replay.py              # Replay one or all scenarios
│   ├── build-install.sh       # xcodebuild + simctl install
│   ├── run-all.sh             # Build, install, replay all
│   └── install-launchd.sh     # Install local cron job
└── launchd/                   # launchd plist template
```

## Recording scenarios

1. Build and install the app:

   ```sh
   ./scripts/build-install.sh
   ```

2. Start the recording helper:

   ```sh
   ./scripts/record.sh
   ```

3. Open Appium Inspector and connect to `127.0.0.1:4791` with capabilities from `appium/capabilities.json`. Add `"appium:deviceName": "iPhone 17"`.

4. Interact with the app. Prefer elements with DXA accessibility IDs (`login-submit`, `deposit-open`, `deposit-amount`, etc.).

5. Export the session as Python (Pytest) and save to `recordings/raw/<name>.py`.

6. Normalize into YAML:

   ```sh
   python3 scripts/normalize.py recordings/raw/<name>.py
   ```

7. Review and commit `scenarios/<name>.yaml`.

## Replaying scenarios

Run all committed scenarios:

```sh
./scripts/run-all.sh
```

Replay a single scenario:

```sh
python3 scripts/replay.py --scenario login-deposit-logout
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RUM_LOADGEN_SIMULATOR` | `iPhone 17` | Simulator device name |
| `RUM_LOADGEN_BUNDLE_ID` | `com.splunk.bankofsplunk` | App bundle ID |
| `RUM_LOADGEN_SCENARIOS_DIR` | `./scenarios` | Scenario directory |
| `RUM_LOADGEN_RUM_FLUSH_SECONDS` | `30` | Wait after backgrounding app for OTLP export |
| `RUM_LOADGEN_APPIUM_URL` | `http://127.0.0.1:4791` | Appium server URL (dedicated port — see note below) |
| `RUM_LOADGEN_SKIP_BUILD` | `0` | Set to `1` to skip build-install |
| `RUM_LOADGEN_START_APPIUM` | `1` | Set to `0` if Appium is already running |

Loadgen builds set `RUM_LOADGEN=1`, which adds global attributes `synthetic=true` and `loadgen.source=ios-rum-loadgen` for filtering in Observability Cloud.

**Why port 4791?** Appium's default port (4723) is commonly occupied by a long-running system service (e.g. `brew services start appium`, which restarts under launchd). That daemon loads its driver manifest once at startup — if you install or update a driver afterward, the running daemon won't know about it, and Appium returns `Could not find a driver for automationName 'XCUITest'` even though `appium driver list --installed` shows it on disk. The loadgen defaults to a private port so it always starts (and controls the lifecycle of) its own fresh Appium process. If you have such a service and prefer to reuse it, restart it after installing/updating drivers (`brew services restart appium`) and point `RUM_LOADGEN_APPIUM_URL` at its port.

## Starter scenarios

| Scenario | Flow |
|----------|------|
| `login-home-logout.yaml` | Sign in → home → sign out |
| `login-deposit-logout.yaml` | Sign in → deposit → sign out |
| `login-payment-logout.yaml` | Sign in → payment → sign out |

Debug builds pre-fill login credentials (`testuser` / `bankofsplunk`).

## Local cron (launchd)

Install a job that replays all scenarios every 30 minutes:

```sh
./scripts/install-launchd.sh
```

Logs: `~/Library/Logs/bank-of-splunk/ios-rum-loadgen.log`

Manual run:

```sh
launchctl kickstart -k gui/$(id -u)/com.splunk.bankofsplunk.ios-rum-loadgen
```

Uninstall:

```sh
launchctl bootout gui/$(id -u)/com.splunk.bankofsplunk.ios-rum-loadgen
rm ~/Library/LaunchAgents/com.splunk.bankofsplunk.ios-rum-loadgen.plist
```

**Note:** The backend must be reachable when the job runs (keep `kubectl port-forward` running for local API).

## GitHub Actions

[`.github/workflows/ios-rum-loadgen.yaml`](../../../.github/workflows/ios-rum-loadgen.yaml) runs every 6 hours on `macos-latest` and can be triggered manually.

Required repository secrets:

- `SPLUNK_RUM_ACCESS_TOKEN`
- `SPLUNK_RUM_REALM`

Optional secrets:

- `SPLUNK_RUM_APP_NAME` (default: `bank-of-splunk-ios`)
- `SPLUNK_RUM_DEPLOYMENT_ENVIRONMENT` (default: `bank-ci`)

CI uses `https://eua-bank.splunko11y.com` as the API base URL (no local Kubernetes required).

## Verify in Observability Cloud

After a replay run, open **RUM for Mobile** (not Browser RUM):

- Filter: `app = bank-of-splunk-ios`
- Filter: `deployment.environment = bank-local` (local) or `bank-ci` (CI)
- Optional: `synthetic = true`

Each session should include `ui.screen_view` events, HTTP spans to `/api/v1/*`, and session replay frames. Allow 30–60 seconds for ingest.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `SPLUNK_RUM_ACCESS_TOKEN is disabled` | Set a real token in `Config/Secrets.xcconfig` |
| Appium not reachable | Run `appium` manually or set `RUM_LOADGEN_START_APPIUM=1` |
| Simulator not found | Set `RUM_LOADGEN_SIMULATOR` to an installed device (`xcrun simctl list devices available`) |
| Login fails in Release build | Use Debug builds (pre-filled credentials) or add `type` steps for username/password |
| No RUM data in dashboard | Confirm replay succeeded (`scenario_complete` in output). Use filters from `verify-rum-config.sh`. The SDK exports via background URLSession — the replay now backgrounds the app for 30s before terminate. Wait 60s and refresh. |
| Replay fails / no scenarios run | Install XCUITest driver: `appium driver install xcuitest`. Check Appium log at `/tmp/bank-of-splunk-appium.log` |
| Login fails during replay | Backend must be reachable at `http://127.0.0.1:8083` — run `kubectl port-forward service/frontend 8083:8083` |

## Related

- iOS app RUM setup: [`../BankOfSplunk/README.md`](../BankOfSplunk/README.md)
- Web RUM loadgen: [`../../../kubernetes-manifests/rum-loadgen.yaml`](../../../kubernetes-manifests/rum-loadgen.yaml)
