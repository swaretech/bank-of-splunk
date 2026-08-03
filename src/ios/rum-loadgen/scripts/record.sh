#!/usr/bin/env bash
# Start Appium and print Appium Inspector connection details for recording.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAPS="$ROOT/appium/capabilities.json"

export RUM_LOADGEN_SIMULATOR="${RUM_LOADGEN_SIMULATOR:-iPhone 17}"
export RUM_LOADGEN_BUNDLE_ID="${RUM_LOADGEN_BUNDLE_ID:-com.splunk.bankofsplunk}"
# Dedicated, non-default port: avoids silently reusing a stale system-wide Appium
# daemon (e.g. `brew services` on 4723) whose driver manifest predates xcuitest install.
export RUM_LOADGEN_APPIUM_URL="${RUM_LOADGEN_APPIUM_URL:-http://127.0.0.1:4791}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing command: $1" >&2
    exit 1
  fi
}

boot_simulator() {
  local udid
  udid="$(xcrun simctl list devices available | grep "${RUM_LOADGEN_SIMULATOR} (" | head -1 | sed -E 's/.* \(([A-F0-9-]+)\).*/\1/')"
  if [ -z "$udid" ]; then
    echo "error: Simulator not found: ${RUM_LOADGEN_SIMULATOR}" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  open -a Simulator >/dev/null 2>&1 || true
  echo "Simulator UDID: $udid"
}

appium_port() {
  if [[ "$RUM_LOADGEN_APPIUM_URL" =~ :([0-9]+)/?$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "4791"
  fi
}

start_appium() {
  if curl -sf "${RUM_LOADGEN_APPIUM_URL}/status" >/dev/null 2>&1; then
    echo "Appium already running at ${RUM_LOADGEN_APPIUM_URL}"
    return
  fi

  echo "Starting Appium at ${RUM_LOADGEN_APPIUM_URL}..."
  appium --address 127.0.0.1 --port "$(appium_port)" --log-no-colors &
  APPIUM_PID=$!

  for _ in $(seq 1 30); do
    if curl -sf "${RUM_LOADGEN_APPIUM_URL}/status" >/dev/null 2>&1; then
      echo "Appium ready (pid ${APPIUM_PID})"
      return
    fi
    sleep 1
  done

  echo "error: Appium failed to start" >&2
  kill "$APPIUM_PID" 2>/dev/null || true
  exit 1
}

main() {
  require_cmd appium
  require_cmd xcrun
  require_cmd curl

  if [ ! -f "$CAPS" ]; then
    echo "error: capabilities file not found: $CAPS" >&2
    exit 1
  fi

  boot_simulator
  start_appium

  cat <<EOF

Recording workflow
==================
1. Open Appium Inspector: https://github.com/appium/appium-inspector/releases
2. Remote connection:
   - Remote Host: 127.0.0.1
   - Remote Port: $(appium_port)
   - Remote Path: /
3. Load capabilities from:
   ${CAPS}
   Add: "appium:deviceName": "${RUM_LOADGEN_SIMULATOR}"
4. Start session, interact with the app, then export as Python (Pytest).
5. Save export to:
   ${ROOT}/recordings/raw/<scenario-name>.py
6. Normalize:
   python3 ${ROOT}/scripts/normalize.py ${ROOT}/recordings/raw/<scenario-name>.py

Tip: prefer tapping elements with DXA accessibility IDs (login-submit, deposit-open, etc.)
EOF
}

main "$@"
