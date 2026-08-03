#!/usr/bin/env bash
# Build the Debug iOS app with RUM enabled and install it on the target simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_ROOT="$(cd "$ROOT/../BankOfSplunk" && pwd)"
SCHEME="BankOfSplunk"
CONFIGURATION="${RUM_LOADGEN_CONFIGURATION:-Debug}"

export RUM_LOADGEN_SIMULATOR="${RUM_LOADGEN_SIMULATOR:-iPhone 17}"
export RUM_LOADGEN_BUNDLE_ID="${RUM_LOADGEN_BUNDLE_ID:-com.splunk.bankofsplunk}"

# Global (not `local`) so the EXIT trap can still reference it after main() returns.
derived_data=""

log() {
  printf '{"event":"%s"%s}\n' "$1" "${2:+,$2}"
}

require_secrets() {
  local secrets_file="$IOS_ROOT/Config/Secrets.xcconfig"
  if [ ! -f "$secrets_file" ]; then
    log build_failed "\"error\":\"Missing $secrets_file — copy Secrets.xcconfig.example and set SPLUNK_RUM_ACCESS_TOKEN\""
    exit 1
  fi

  if grep -Eq '^[[:space:]]*SPLUNK_RUM_ACCESS_TOKEN[[:space:]]*=[[:space:]]*disabled[[:space:]]*$' "$secrets_file"; then
    log build_failed "\"error\":\"SPLUNK_RUM_ACCESS_TOKEN is disabled — set a real token for loadgen builds\""
    exit 1
  fi
}

resolve_simulator_udid() {
  local udid
  udid="$(xcrun simctl list devices available | grep "${RUM_LOADGEN_SIMULATOR} (" | head -1 | sed -E 's/.* \(([A-F0-9-]+)\).*/\1/')"
  if [ -z "$udid" ]; then
    log build_failed "\"error\":\"Simulator not found: ${RUM_LOADGEN_SIMULATOR}\""
    exit 1
  fi
  echo "$udid"
}

main() {
  require_secrets

  local udid
  udid="$(resolve_simulator_udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true

  log build_start "\"scheme\":\"${SCHEME}\",\"simulator\":\"${RUM_LOADGEN_SIMULATOR}\""

  derived_data="$(mktemp -d "${TMPDIR:-/tmp}/bank-of-splunk-derived.XXXXXX")"
  trap 'rm -rf "$derived_data"' EXIT

  xcodebuild \
    -project "$IOS_ROOT/BankOfSplunk.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,name=${RUM_LOADGEN_SIMULATOR},OS=latest" \
    -derivedDataPath "$derived_data" \
    RUM_LOADGEN=1 \
    build

  local app_path
  app_path="$(find "$derived_data/Build/Products" -maxdepth 2 -name "${SCHEME}.app" -type d | head -1)"
  if [ -z "$app_path" ]; then
    log build_failed "\"error\":\"Built .app not found under $derived_data/Build/Products\""
    exit 1
  fi

  xcrun simctl install "$udid" "$app_path"
  log build_complete "\"app\":\"${app_path}\",\"udid\":\"${udid}\""
}

main "$@"
