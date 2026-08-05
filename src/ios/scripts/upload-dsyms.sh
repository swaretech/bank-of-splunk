#!/usr/bin/env bash
# Upload iOS dSYMs to Splunk RUM for crash symbolication and DXA element picker resolution.
# Requires SPLUNK_ACCESS_TOKEN (org API token, not RUM token) and SPLUNK_REALM.
# See: https://help.splunk.com/en/splunk-observability-cloud/manage-data/instrument-front-end-applications/instrument-mobile-and-web-applications-for-splunk-real-user-monitoring-rum/instrument-ios-applications-for-splunk-rum/splunk-rum-ios-agent-version-2.0.0-and-above/add-dsyms
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/node_modules/.bin/splunk-rum"
DSYM_PATH="${1:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <path-to-dSYMs-directory>

Upload dSYMs for the Bank of Splunk iOS app to Splunk RUM.

Environment:
  SPLUNK_ACCESS_TOKEN  Org API access token (power role, API scope — not the RUM token)
  SPLUNK_REALM         Splunk Observability realm (e.g. us0)

Example (after Release archive):
  export SPLUNK_ACCESS_TOKEN=your-org-token
  export SPLUNK_REALM=us0
  ./scripts/upload-dsyms.sh ~/Library/Developer/Xcode/Archives/.../dSYMs

Install CLI first:
  ./scripts/install-splunk-rum-cli.sh
EOF
}

if [ -z "$DSYM_PATH" ]; then
  usage >&2
  exit 1
fi

if [ ! -d "$DSYM_PATH" ] && [ ! -f "$DSYM_PATH" ]; then
  echo "error: dSYM path not found: $DSYM_PATH" >&2
  exit 1
fi

if [ ! -x "$CLI" ]; then
  echo "error: splunk-rum CLI not installed. Run: $ROOT/scripts/install-splunk-rum-cli.sh" >&2
  exit 1
fi

if [ -z "${SPLUNK_ACCESS_TOKEN:-}" ]; then
  echo "error: SPLUNK_ACCESS_TOKEN is not set (org API token, not RUM token)" >&2
  exit 1
fi

if [ -z "${SPLUNK_REALM:-}" ]; then
  echo "error: SPLUNK_REALM is not set (e.g. us0)" >&2
  exit 1
fi

echo "Uploading dSYMs from: $DSYM_PATH"
"$CLI" ios upload --path "$DSYM_PATH"
echo "Upload complete. Verify with: $CLI ios list"
