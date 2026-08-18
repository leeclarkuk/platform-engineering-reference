#!/usr/bin/env bash
# Experiment 1: delete a pod and prove the service recovers.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_kubectl

echo "== pod-delete: baseline request"
body="$(request_ok || true)"
if [[ "$body" != *"ok"* ]]; then
  echo "baseline request failed: $body"
  exit 1
fi

pod="$(kubectl --namespace "$NAMESPACE" get pod -l "app.kubernetes.io/name=$SERVICE" \
  -o jsonpath='{.items[0].metadata.name}')"
echo "deleting $pod"
start="$(python3 -c 'import time; print(time.time())')"
kubectl --namespace "$NAMESPACE" delete pod "$pod" --wait=true

echo "waiting for replacement to be ready"
kubectl --namespace "$NAMESPACE" wait --for=condition=available --timeout=180s "deployment/$SERVICE"
after="$(request_ok || true)"
ms="$(elapsed_ms "$start")"

if [[ "$after" != *"ok"* ]]; then
  echo "service did not recover after pod deletion: $after"
  exit 1
fi

echo "detection: ReplicaSet noticed missing replica"
echo "replacement: new pod ready"
echo "readiness: GET / returned ok"
echo "approximate recovery_ms=$ms"
echo "pod-delete OK"
