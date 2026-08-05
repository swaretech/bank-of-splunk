#!/usr/bin/env bash
# Install the Splunk RUM CLI (@splunk/rum-cli) for iOS dSYM upload.
# Requires Node.js 18+. See:
# https://help.splunk.com/en/splunk-observability-cloud/manage-data/instrument-front-end-applications/instrument-mobile-and-web-applications-for-splunk-real-user-monitoring-rum#d0a055191a9234efead01e6d18d028311--en__install-splunk-rum
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
  echo "error: Node.js 18+ is required. Install from https://nodejs.org/" >&2
  exit 1
fi

node_major="$(node -p "process.versions.node.split('.')[0]")"
if [ "$node_major" -lt 18 ]; then
  echo "error: Node.js 18+ is required (found $(node -v))" >&2
  exit 1
fi

npm install
echo "splunk-rum CLI installed: $ROOT/node_modules/.bin/splunk-rum"
"$ROOT/node_modules/.bin/splunk-rum" --help | head -5
