# iOS RUM Load Generator

Replay user scenarios on the Bank of Splunk iOS app to generate real Splunk RUM mobile sessions on your Mac.

Appium drives the app in the iOS Simulator. The Splunk RUM SDK exports OTLP traces and session replay to Observability Cloud — sessions are not injected via the ingest API.

## Quick start

From a terminal:

```sh
# 1. Start the backend (separate terminal — keep running)
kubectl --context k3d-bank-of-splunk port-forward service/frontend 8083:8083

# 2. Configure RUM (once)
cd src/ios/BankOfSplunk
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Edit Secrets.xcconfig: set SPLUNK_RUM_ACCESS_TOKEN to your RUM token

# 3. One-time loadgen setup
cd ../rum-loadgen
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
npm install -g appium
appium driver install xcuitest

# 4. Build, replay all scenarios, send RUM sessions
./scripts/run-all.sh
```

After replay, open **RUM for Mobile** in Observability Cloud (not Browser RUM):

- `app = bank-of-splunk-ios`
- `deployment.environment = bank-local`
- Optional: `synthetic = true`

Allow 30–60 seconds for ingest.

## Prerequisites

- macOS with Xcode 15+ and an iOS Simulator (e.g. iPhone 17)
- Python 3.12+, Node.js 20+, Appium 2.x with XCUITest driver
- Bank of Splunk backend on `http://127.0.0.1:8083` (k3d + port-forward)
- `src/ios/BankOfSplunk/Config/Secrets.xcconfig` with a real `SPLUNK_RUM_ACCESS_TOKEN`

## Common commands

| Goal | Command |
|------|---------|
| Build + install app on simulator | `./scripts/build-install.sh` |
| Replay all scenarios | `./scripts/run-all.sh` |
| Replay one scenario | `python3 scripts/replay.py --scenario login-deposit-logout` |
| Verify RUM config in installed app | `./scripts/verify-rum-config.sh` |
| Record new scenario (Appium Inspector) | `./scripts/record.sh` |
| Normalize Inspector export to YAML | `python3 scripts/normalize.py recordings/raw/<name>.py` |
| Schedule replay every 30 min (launchd) | `./scripts/install-launchd.sh` |

Skip rebuild when the app is already installed:

```sh
RUM_LOADGEN_SKIP_BUILD=1 ./scripts/run-all.sh
```

## Local hosting

The iOS app and loadgen expect the Bank of Splunk API at `http://127.0.0.1:8083` (set in `Secrets.xcconfig` as `API_BASE_URL`).

1. Deploy the backend locally — see [`../BankOfSplunk/README.md`](../BankOfSplunk/README.md)
2. Port-forward the frontend:

   ```sh
   kubectl --context k3d-bank-of-splunk port-forward service/frontend 8083:8083
   ```

3. Confirm the API:

   ```sh
   curl -s -X POST http://127.0.0.1:8083/api/v1/login \
     -H 'Content-Type: application/json' \
     -d '{"username":"testuser","password":"bankofsplunk"}'
   ```

Loadgen builds pass `RUM_LOADGEN=1`, adding global attributes `synthetic=true` and `loadgen.source=ios-rum-loadgen` so you can filter synthetic sessions in Observability Cloud.

## Starter scenarios

| Scenario | Flow |
|----------|------|
| `login-home-logout.yaml` | Sign in → home → sign out |
| `login-deposit-logout.yaml` | Sign in → deposit → sign out |
| `login-payment-logout.yaml` | Sign in → payment → sign out |

Debug builds pre-fill login credentials (`testuser` / `bankofsplunk`).

## Recording new scenarios

1. `./scripts/build-install.sh`
2. `./scripts/record.sh`
3. Connect Appium Inspector to `127.0.0.1:4791` with `appium/capabilities.json` (+ `"appium:deviceName": "iPhone 17"`)
4. Export interactions as Python → save to `recordings/raw/<name>.py`
5. `python3 scripts/normalize.py recordings/raw/<name>.py`
6. Review and commit `scenarios/<name>.yaml`

Prefer DXA accessibility IDs (`login-submit`, `deposit-open`, `deposit-amount`, etc.).

## Scheduled replay (optional)

```sh
./scripts/install-launchd.sh
```

Logs: `~/Library/Logs/bank-of-splunk/ios-rum-loadgen.log`

The backend port-forward must stay running while the job executes.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RUM_LOADGEN_SIMULATOR` | `iPhone 17` | Simulator device name |
| `RUM_LOADGEN_API_URL` | `http://127.0.0.1:8083` | Backend API for preflight check |
| `RUM_LOADGEN_APPIUM_URL` | `http://127.0.0.1:4791` | Dedicated Appium port (avoids stale `brew services` daemon on 4723) |
| `RUM_LOADGEN_RUM_FLUSH_SECONDS` | `30` | Background time for RUM export before app terminate |
| `RUM_LOADGEN_SKIP_BUILD` | `0` | Set to `1` to skip build-install |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `api_unreachable` | Start `kubectl port-forward service/frontend 8083:8083` |
| `SPLUNK_RUM_ACCESS_TOKEN is disabled` | Set a real token in `Secrets.xcconfig` |
| XCUITest driver not found | `appium driver install xcuitest` |
| No RUM sessions in dashboard | Confirm `scenario_complete` in output; run `./scripts/verify-rum-config.sh`; wait 60s |
| Appium port conflict | Loadgen uses 4791 by default; restart stale daemon with `brew services restart appium` if needed |

## Related

- iOS app setup: [`../BankOfSplunk/README.md`](../BankOfSplunk/README.md)
- Web RUM loadgen (Kubernetes): [`../../../kubernetes-manifests/rum-loadgen.yaml`](../../../kubernetes-manifests/rum-loadgen.yaml)
