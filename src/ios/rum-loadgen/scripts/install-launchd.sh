#!/usr/bin/env bash
# Install the local launchd job for iOS RUM loadgen replays.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$ROOT/launchd/com.splunk.bankofsplunk.ios-rum-loadgen.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.splunk.bankofsplunk.ios-rum-loadgen.plist"
LOG_DIR="$HOME/Library/Logs/bank-of-splunk"

mkdir -p "$LOG_DIR"

sed \
  -e "s|REPO_ROOT|$ROOT|g" \
  -e "s|HOME|$HOME|g" \
  "$PLIST_SRC" > "$PLIST_DEST"

launchctl bootout "gui/$(id -u)/com.splunk.bankofsplunk.ios-rum-loadgen" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"

echo "Installed launchd job: $PLIST_DEST"
echo "Logs: $LOG_DIR/ios-rum-loadgen.log"
echo "Run now: launchctl kickstart -k gui/$(id -u)/com.splunk.bankofsplunk.ios-rum-loadgen"
