#!/usr/bin/env bash
# Experiment 2: apply an unhealthy Deployment and prove probes fail.
# This object is separate from the golden-path Deployment so Argo CD is
# not fighting the experiment. The bad object should stay unready.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
require_kubectl

echo "== bad-deployment: apply fixture"
kubectl apply -f "$root/resilience/failure-lab/fixtures/bad-deployment.yaml"

echo "waiting long enough for probes to fail (20s)"
sleep 20

ready="$(kubectl --namespace "$NAMESPACE" get deploy sample-service-bad \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
ready="${ready:-0}"
if [[ "$ready" != "0" && "$ready" != "" ]]; then
  echo "FAIL: bad deployment reported readyReplicas=$ready"
  kubectl --namespace "$NAMESPACE" delete deploy sample-service-bad --ignore-not-found
  exit 1
fi

echo "Kubernetes readiness failed as expected (readyReplicas=${ready:-0})"
echo "The golden-path service must still answer"
body="$(request_ok || true)"
if [[ "$body" != *"ok"* ]]; then
  echo "FAIL: healthy service was affected: $body"
  kubectl --namespace "$NAMESPACE" delete deploy sample-service-bad --ignore-not-found
  exit 1
fi

echo "Argo CD: the sample-service Application should remain Healthy."
echo "sample-service-bad is not an Application. It should not look like a successful rollout."
kubectl --namespace "$NAMESPACE" delete deploy sample-service-bad --wait=true
echo "bad-deployment OK"
