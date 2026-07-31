#!/usr/bin/env bash
# Install Splunk OTel Collector for local Option B APM (default namespace).
# Required: SPLUNK_REALM, SPLUNK_ACCESS_TOKEN (Observability access token, NOT rum_token)
# Optional: CLUSTER_NAME (default: bank-of-splunk-k3s-cluster), KUBE_CONTEXT
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
KUBECTL=(kubectl)
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBECTL+=(--context "$KUBE_CONTEXT")
fi

if [[ -z "${SPLUNK_REALM:-}" ]]; then
  echo "error: SPLUNK_REALM is required (or set workshop-secret key realm before running)" >&2
  exit 1
fi

if [[ -z "${SPLUNK_ACCESS_TOKEN:-}" ]]; then
  echo "error: SPLUNK_ACCESS_TOKEN is required for backend APM" >&2
  exit 1
fi

helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart 2>/dev/null || true
helm repo update splunk-otel-collector-chart

HELM=(helm)
if [[ -n "$KUBE_CONTEXT" ]]; then
  HELM+=(--kube-context "$KUBE_CONTEXT")
fi

"${HELM[@]}" upgrade --install splunk-otel-collector splunk-otel-collector-chart/splunk-otel-collector \
  --namespace default --create-namespace \
  --set "splunkObservability.realm=${SPLUNK_REALM}" \
  --set "splunkObservability.accessToken=${SPLUNK_ACCESS_TOKEN}" \
  --set "clusterName=${CLUSTER_NAME:-bank-of-splunk-k3s-cluster}" \
  --set environment=local \
  --set operatorcrds.install=true \
  --set operator.enabled=true \
  --set agent.service.enabled=true \
  -f extras/local-k8s/otel-collector-values.yaml

"${KUBECTL[@]}" rollout status daemonset/splunk-otel-collector-agent -n default --timeout=120s
echo "Splunk OTel Collector is ready in namespace default."
