#!/usr/bin/env bash
# Build Bank of Splunk from source and deploy to a local k3d cluster (Option B).
# See README.md "Quickstart (Local Kubernetes)" for prerequisites and context.
#
# Optional APM env vars (Splunk OTel Collector):
#   SPLUNK_ACCESS_TOKEN  Observability access token (not rum_token)
#   SPLUNK_REALM         Splunk realm (defaults to workshop-secret key realm)
#   SKIP_COLLECTOR       Set to true to skip collector install
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CLUSTER="${CLUSTER:-bank-of-splunk}"
KUBE_CONTEXT="${KUBE_CONTEXT:-k3d-${CLUSTER}}"
REPO="${REPO:-bank-of-splunk}"
TAG="${TAG:-local}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_COLLECTOR="${SKIP_COLLECTOR:-false}"

# Detect node architecture (arm64 on Apple Silicon, amd64 on most Linux/Intel Mac).
NODE_ARCH="$(kubectl --context "$KUBE_CONTEXT" get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}' 2>/dev/null || uname -m)"
case "$NODE_ARCH" in
  arm64|aarch64) PLATFORM=linux/arm64; JIB_FROM=eclipse-temurin:17-jre; JIB_PLATFORM=linux/arm64 ;;
  *)             PLATFORM=linux/amd64; JIB_FROM=eclipse-temurin:17-jre-alpine; JIB_PLATFORM=linux/amd64 ;;
esac

# JDK 21 for Jib/Maven (Homebrew keg-only install).
if [[ -d /opt/homebrew/opt/openjdk@21/bin ]]; then
  export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
  export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
fi

# Docker Desktop's internal HTTP proxy breaks apt-get inside Debian-based build stages.
# Clearing proxy build-args lets builds reach public package mirrors on the host network.
DOCKER_PROXY_ARGS=(
  --build-arg HTTP_PROXY=
  --build-arg HTTPS_PROXY=
  --build-arg http_proxy=
  --build-arg https_proxy=
)

build_py() {
  local name=$1 context=$2
  echo "==> Building ${REPO}/${name}:${TAG} (${PLATFORM})"
  docker build "${DOCKER_PROXY_ARGS[@]}" -t "${REPO}/${name}:${TAG}" "$context"
}

deploy_kustomize() {
  local name=$1 path=$2
  echo "==> Deploying ${name}"
  kubectl --context "$KUBE_CONTEXT" kustomize "$path" \
    | sed "s|image: ${name}|image: ${REPO}/${name}:${TAG}|" \
    | kubectl --context "$KUBE_CONTEXT" apply -f -
}

# Skaffold-compatible manifest of locally built images. Ephemeral, gitignored, and
# not consumed by CI or release pipelines — for local tooling and debugging only.
write_local_build_artifacts() {
  local out="${ROOT}/.local-build-artifacts.json"
  python3 - "$out" "$REPO" "$TAG" <<'PY'
import json
import subprocess
import sys

out, repo, tag = sys.argv[1], sys.argv[2], sys.argv[3]
app_images = (
    "frontend",
    "contacts",
    "userservice",
    "loadgenerator",
    "balancereader",
    "ledgerwriter",
    "transactionhistory",
)
builds = [{"imageName": name, "tag": f"{repo}/{name}:{tag}"} for name in app_images]

for db in ("accounts-db", "ledger-db"):
    result = subprocess.run(
        ["docker", "images", f"{repo}/{db}", "--format", "{{.Tag}}"],
        capture_output=True,
        text=True,
        check=False,
    )
    tags = [t for t in result.stdout.splitlines() if t and t != "<none>"]
    sha_tags = [
        t for t in tags if len(t) == 64 and all(c in "0123456789abcdef" for c in t)
    ]
    if sha_tags:
        builds.append({"imageName": db, "tag": f"{repo}/{db}:{sha_tags[0]}"})
    elif tags:
        builds.append({"imageName": db, "tag": f"{repo}/{db}:{tags[0]}"})

with open(out, "w", encoding="utf-8") as fh:
    json.dump({"builds": builds}, fh, indent=2)
    fh.write("\n")
print(f"==> Wrote {out}")
PY
}

echo "Using kube context: ${KUBE_CONTEXT}  platform: ${PLATFORM}"

kubectl --context "$KUBE_CONTEXT" apply -f ./extras/jwt/jwt-secret.yaml
kubectl --context "$KUBE_CONTEXT" apply -f ./kubernetes-manifests/config.yaml
kubectl --context "$KUBE_CONTEXT" apply -f ./iac/acm-multienv-cicd-anthos-autopilot/base/sa.yaml

# Dev overlays read four keys from workshop-secret (see src/frontend/k8s/base/frontend.yaml).
if ! kubectl --context "$KUBE_CONTEXT" get secret workshop-secret >/dev/null 2>&1; then
  kubectl --context "$KUBE_CONTEXT" create secret generic workshop-secret \
    --from-literal=realm=us0 \
    --from-literal=rum_token=disabled \
    --from-literal=app=bank-of-splunk \
    --from-literal=env=local
else
  kubectl --context "$KUBE_CONTEXT" patch secret workshop-secret --type merge \
    -p '{"stringData":{"app":"bank-of-splunk","env":"local"}}' >/dev/null || true
fi

if [[ "$SKIP_COLLECTOR" != "true" ]]; then
  if [[ -n "${SPLUNK_ACCESS_TOKEN:-}" ]]; then
    if [[ -z "${SPLUNK_REALM:-}" ]] && kubectl --context "$KUBE_CONTEXT" get secret workshop-secret >/dev/null 2>&1; then
      SPLUNK_REALM="$(kubectl --context "$KUBE_CONTEXT" get secret workshop-secret -o jsonpath='{.data.realm}' | base64 -d)"
      export SPLUNK_REALM
    fi
    echo "==> Installing Splunk OTel Collector (APM)"
    KUBE_CONTEXT="$KUBE_CONTEXT" "$ROOT/extras/local-k8s/install-splunk-otel-collector.sh"
  else
    echo "warning: SPLUNK_ACCESS_TOKEN not set — backend APM traces will be dropped (RUM/DXA unaffected)" >&2
  fi
fi

skaffold config set --kube-context "$KUBE_CONTEXT" local-cluster true

if [[ "$SKIP_BUILD" != "true" ]]; then
  echo "==> Building and deploying databases"
  skaffold run --kube-context "$KUBE_CONTEXT" --module=accounts-db --profile=development \
    --default-repo="$REPO" --platform="$PLATFORM" --skip-tests=true
  skaffold run --kube-context "$KUBE_CONTEXT" --module=ledger-db --profile=development \
    --default-repo="$REPO" --platform="$PLATFORM" --skip-tests=true

  echo "==> Building application images"
  build_py frontend src/frontend
  build_py contacts src/accounts/contacts
  build_py userservice src/accounts/userservice
  build_py loadgenerator src/loadgenerator

  JIB_ARGS=(-DskipTests "-Djib.from.image=${JIB_FROM}" "-Djib.from.platforms=${JIB_PLATFORM}")
  ./mvnw -q -pl src/ledger/balancereader -am package jib:dockerBuild \
    "${JIB_ARGS[@]}" -Djib.to.image="${REPO}/balancereader:${TAG}"
  ./mvnw -q -pl src/ledger/ledgerwriter -am package jib:dockerBuild \
    "${JIB_ARGS[@]}" -Djib.to.image="${REPO}/ledgerwriter:${TAG}"
  ./mvnw -q -pl src/ledger/transactionhistory -am package jib:dockerBuild \
    "${JIB_ARGS[@]}" -Djib.to.image="${REPO}/transactionhistory:${TAG}"

  echo "==> Importing images into k3d"
  k3d image import \
    "${REPO}/frontend:${TAG}" \
    "${REPO}/contacts:${TAG}" \
    "${REPO}/userservice:${TAG}" \
    "${REPO}/loadgenerator:${TAG}" \
    "${REPO}/balancereader:${TAG}" \
    "${REPO}/ledgerwriter:${TAG}" \
    "${REPO}/transactionhistory:${TAG}" \
    -c "$CLUSTER"

  write_local_build_artifacts
fi

deploy_kustomize frontend src/frontend/k8s/overlays/development
deploy_kustomize contacts src/accounts/contacts/k8s/overlays/development
deploy_kustomize userservice src/accounts/userservice/k8s/overlays/development
deploy_kustomize balancereader src/ledger/balancereader/k8s/overlays/development
deploy_kustomize ledgerwriter src/ledger/ledgerwriter/k8s/overlays/development
deploy_kustomize transactionhistory src/ledger/transactionhistory/k8s/overlays/development
deploy_kustomize loadgenerator src/loadgenerator/k8s/overlays/development

kubectl --context "$KUBE_CONTEXT" rollout status deployment/frontend --timeout=120s
kubectl --context "$KUBE_CONTEXT" get pods

echo
echo "Done. Port-forward the frontend:"
echo "  kubectl --context ${KUBE_CONTEXT} port-forward service/frontend 8083:8083"
echo "Then open http://localhost:8083  (login: testuser / bankofsplunk)"
