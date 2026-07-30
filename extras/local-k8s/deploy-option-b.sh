#!/usr/bin/env bash
# Build Bank of Splunk from source and deploy to a local k3d cluster (Option B).
# See README.md "Quickstart (Local Kubernetes)" for prerequisites and context.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CLUSTER="${CLUSTER:-bank-of-splunk}"
KUBE_CONTEXT="${KUBE_CONTEXT:-k3d-${CLUSTER}}"
REPO="${REPO:-bank-of-splunk}"
TAG="${TAG:-local}"
SKIP_BUILD="${SKIP_BUILD:-false}"

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
