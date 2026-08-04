#!/usr/bin/env bash
# Build, install, and replay all iOS RUM loadgen scenarios.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/scripts"

export RUM_LOADGEN_SIMULATOR="${RUM_LOADGEN_SIMULATOR:-iPhone 17}"
export RUM_LOADGEN_BUNDLE_ID="${RUM_LOADGEN_BUNDLE_ID:-com.splunk.bankofsplunk}"
export RUM_LOADGEN_RUM_FLUSH_SECONDS="${RUM_LOADGEN_RUM_FLUSH_SECONDS:-30}"
# Dedicated, non-default port: avoids silently reusing a stale system-wide Appium
# server (e.g. `brew services` on 4723) whose driver manifest predates xcuitest install.
export RUM_LOADGEN_APPIUM_URL="${RUM_LOADGEN_APPIUM_URL:-http://127.0.0.1:4791}"

log() {
  printf '{"event":"%s"%s}\n' "$1" "${2:+,$2}"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log run_all_failed "\"error\":\"missing command: $1\""
    exit 1
  fi
}

require_appium_driver() {
  if ! command -v appium >/dev/null 2>&1; then
    log run_all_failed "\"error\":\"appium not installed — run: npm install -g appium && appium driver install xcuitest\""
    exit 1
  fi
  # Appium 3.x writes driver list to stderr; use JSON on stdout for a reliable check.
  if ! appium driver list --installed --json 2>/dev/null \
    | python3 -c "import json, sys; sys.exit(0 if 'xcuitest' in json.load(sys.stdin) else 1)"; then
    log run_all_failed "\"error\":\"XCUITest driver not installed — run: appium driver install xcuitest\""
    exit 1
  fi
}

check_api() {
  local api_url="${RUM_LOADGEN_API_URL:-http://127.0.0.1:8083}"
  local hint="start kubectl port-forward service/frontend 8083:8083"
  if [ "${RUM_LOADGEN_REQUIRE_API:-0}" = "1" ]; then
    hint="verify the hosted API URL is reachable (RUM_LOADGEN_API_URL)"
  fi

  if ! curl -sf "${api_url}/api/v1/login" \
    -X POST -H 'Content-Type: application/json' \
    -d '{"username":"testuser","password":"bankofsplunk"}' >/dev/null; then
    log api_unreachable "\"url\":\"${api_url}\",\"hint\":\"${hint}\""
    if [ "${RUM_LOADGEN_REQUIRE_API:-0}" = "1" ]; then
      log run_all_failed "\"error\":\"API unreachable at ${api_url}\""
      exit 1
    fi
  else
    log api_ok "\"url\":\"${api_url}\""
  fi
}

appium_port() {
  if [[ "$RUM_LOADGEN_APPIUM_URL" =~ :([0-9]+)/?$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "4791"
  fi
}

wait_for_appium() {
  local retries=30
  while [ "$retries" -gt 0 ]; do
    if curl -sf "${RUM_LOADGEN_APPIUM_URL}/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    retries=$((retries - 1))
  done
  log run_all_failed "\"error\":\"Appium server not reachable at ${RUM_LOADGEN_APPIUM_URL}\""
  exit 1
}

ensure_simulator() {
  local udid=""
  local devices
  devices="$(xcrun simctl list devices available)"
  for candidate in "${RUM_LOADGEN_SIMULATOR}" "iPhone 15" "iPhone 16" "iPhone 17"; do
    udid="$(printf '%s\n' "$devices" | grep -F "${candidate} (" | head -1 | sed -E 's/.* \(([A-F0-9-]+)\).*/\1/' || true)"
    if [ -n "$udid" ]; then
      export RUM_LOADGEN_SIMULATOR="$candidate"
      break
    fi
  done

  if [ -z "$udid" ]; then
    log run_all_failed "\"error\":\"No compatible iPhone simulator found (tried ${RUM_LOADGEN_SIMULATOR}, iPhone 15, iPhone 16, iPhone 17)\""
    exit 1
  fi

  export RUM_LOADGEN_SIMULATOR_UDID="$udid"
  log simulator_ready "\"name\":\"${RUM_LOADGEN_SIMULATOR}\",\"udid\":\"${udid}\""
  xcrun simctl boot "$udid" 2>/dev/null || true
  open -a Simulator >/dev/null 2>&1 || true
}

start_appium_if_needed() {
  if curl -sf "${RUM_LOADGEN_APPIUM_URL}/status" >/dev/null 2>&1; then
    log appium_ready "\"source\":\"existing\""
    return
  fi

  if [ "${RUM_LOADGEN_START_APPIUM:-1}" != "1" ]; then
    log run_all_failed "\"error\":\"Appium not running and RUM_LOADGEN_START_APPIUM=0\""
    exit 1
  fi

  log appium_starting "\"url\":\"${RUM_LOADGEN_APPIUM_URL}\""
  appium --address 127.0.0.1 --port "$(appium_port)" --log-no-colors \
    >"${TMPDIR:-/tmp}/bank-of-splunk-appium.log" 2>&1 &
  APPIUM_PID=$!
  trap 'kill "$APPIUM_PID" 2>/dev/null || true' EXIT
  wait_for_appium
}

main() {
  require_cmd python3
  require_cmd xcrun
  require_cmd curl
  require_appium_driver

  log run_all_start "\"simulator\":\"${RUM_LOADGEN_SIMULATOR}\""

  check_api

  if [ "${RUM_LOADGEN_SKIP_BUILD:-0}" != "1" ]; then
    "$SCRIPTS/build-install.sh"
  fi

  ensure_simulator
  "$SCRIPTS/verify-rum-config.sh"
  start_appium_if_needed

  if [ -d "$ROOT/.venv" ]; then
    # shellcheck disable=SC1091
    source "$ROOT/.venv/bin/activate"
  fi

  python3 "$SCRIPTS/replay.py" --scenarios-dir "$ROOT/scenarios"
  replay_status=$?
  if [ "$replay_status" -ne 0 ]; then
    log run_all_failed "\"error\":\"One or more scenarios failed — RUM sessions require successful replay\""
    exit "$replay_status"
  fi

  log run_all_complete "\"hint\":\"Check RUM for Mobile with filters printed above; wait 30-60s for ingest\""
}

main "$@"
