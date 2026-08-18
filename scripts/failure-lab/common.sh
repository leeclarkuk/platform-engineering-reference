#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-sample-service}"
SERVICE="${SERVICE:-sample-service}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required"
    exit 1
  fi
  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "No reachable cluster. Failure experiments are NOT PROVED without kubeconfig."
    exit 1
  fi
}

ensure_probe_pod() {
  kubectl apply -f "$root/resilience/failure-lab/fixtures/probe-pod.yaml" >/dev/null
  kubectl --namespace "$NAMESPACE" wait --for=condition=Ready --timeout=90s pod/sample-service-probe
}

request_ok() {
  ensure_probe_pod
  kubectl --namespace "$NAMESPACE" exec sample-service-probe -- \
    wget -qO- --timeout=8 "http://${SERVICE}:8080/"
}

elapsed_ms() {
  local start="$1"
  python3 - "$start" <<'PY'
import sys, time
start = float(sys.argv[1])
print(int((time.time() - start) * 1000))
PY
}
