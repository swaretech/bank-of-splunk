#!/usr/bin/env bash
# Verify the installed app has RUM enabled (does not print secrets).
set -euo pipefail

BUNDLE_ID="${RUM_LOADGEN_BUNDLE_ID:-com.splunk.bankofsplunk}"
SIMULATOR_UDID="${RUM_LOADGEN_SIMULATOR_UDID:-}"

log() {
  printf '{"event":"%s"%s}\n' "$1" "${2:+,$2}"
}

resolve_app_path() {
  local udid="$1"
  xcrun simctl get_app_container "$udid" "$BUNDLE_ID" app 2>/dev/null
}

main() {
  local udid="$SIMULATOR_UDID"
  if [ -z "$udid" ]; then
    udid="$(xcrun simctl list devices booted | sed -n 's/.*(\([A-F0-9-]*\)) (Booted).*/\1/p' | head -1)"
  fi

  if [ -z "$udid" ]; then
    log rum_verify_failed "\"error\":\"No booted simulator found\""
    exit 1
  fi

  local app_path
  app_path="$(resolve_app_path "$udid")"
  if [ -z "$app_path" ] || [ ! -f "$app_path/Info.plist" ]; then
    log rum_verify_failed "\"error\":\"App not installed on simulator ($BUNDLE_ID)\""
    exit 1
  fi

  local token realm app_name env loadgen
  token="$(/usr/libexec/PlistBuddy -c 'Print :SplunkRumAccessToken' "$app_path/Info.plist" 2>/dev/null || echo "")"
  realm="$(/usr/libexec/PlistBuddy -c 'Print :SplunkRumRealm' "$app_path/Info.plist" 2>/dev/null || echo "")"
  app_name="$(/usr/libexec/PlistBuddy -c 'Print :SplunkRumAppName' "$app_path/Info.plist" 2>/dev/null || echo "")"
  env="$(/usr/libexec/PlistBuddy -c 'Print :SplunkRumDeploymentEnvironment' "$app_path/Info.plist" 2>/dev/null || echo "")"
  loadgen="$(/usr/libexec/PlistBuddy -c 'Print :RumLoadgenEnabled' "$app_path/Info.plist" 2>/dev/null || echo "")"

  if [ -z "$token" ] || [ "$token" = "disabled" ] || [ "$token" = "not-found" ]; then
    log rum_verify_failed "\"error\":\"RUM token not configured in installed app (got: ${token:-empty})\""
    exit 1
  fi

  log rum_verify_ok \
    "\"realm\":\"${realm}\",\"app\":\"${app_name}\",\"deployment_environment\":\"${env}\",\"loadgen\":\"${loadgen}\",\"token_length\":${#token}"

  cat <<EOF

Dashboard filters (RUM for Mobile):
  app = ${app_name}
  deployment.environment = ${env}
EOF
  if [ "$loadgen" = "1" ]; then
    echo "  synthetic = true"
  fi
  echo "Allow 30-60 seconds after replay for ingest."
}

main "$@"
