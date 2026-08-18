#!/usr/bin/env bash
# Experiment 3: deny ingress to the sample service. The control plane
# stays healthy. Application traffic fails.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
require_kubectl

cleanup() {
  kubectl --namespace "$NAMESPACE" delete -f "$root/resilience/failure-lab/fixtures/deny-ingress.yaml" --ignore-not-found >/dev/null 2>&1 || true
  # Restore is GitOps-owned. If Argo CD is running it will put the allow policy back.
  echo "cleanup: removed deny-ingress. If Argo CD is paused, re-sync sample-service to restore the allow policy."
}
trap cleanup EXIT

echo "== network-policy: baseline"
body="$(request_ok || true)"
if [[ "$body" != *"ok"* ]]; then
  echo "baseline request failed: $body"
  exit 1
fi

echo "replacing the golden-path NetworkPolicy with deny-ingress"
kubectl --namespace "$NAMESPACE" delete networkpolicy "$SERVICE" --ignore-not-found >/dev/null
kubectl apply -f "$root/resilience/failure-lab/fixtures/deny-ingress.yaml"
sleep 5

blocked="$(request_ok || true)"
if [[ "$blocked" == *"ok"* ]]; then
  echo "FAIL: request still succeeded after deny-ingress. NetworkPolicy may be unimplemented (for example Amazon VPC CNI without policy)."
  exit 1
fi

echo "application traffic failed as expected"
deploy_ok="$(kubectl --namespace "$NAMESPACE" get deploy "$SERVICE" -o jsonpath='{.status.readyReplicas}')"
if [[ -z "$deploy_ok" || "$deploy_ok" == "0" ]]; then
  echo "FAIL: control plane also looks down. This experiment should isolate network policy."
  exit 1
fi
echo "deployment still reports readyReplicas=$deploy_ok"
echo "network-policy OK"
