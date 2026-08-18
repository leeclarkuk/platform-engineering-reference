#!/usr/bin/env bash
# Prove the sample application answers. Infrastructure health is not enough.
set -euo pipefail

PROVIDER="${PROVIDER:-aws}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
NAMESPACE="${NAMESPACE:-sample-service}"
SERVICE="${SERVICE:-sample-service}"
EXPECTED="${EXPECTED:-ok}"

if [[ "$PROVIDER" != "aws" ]]; then
  echo "verify-live currently implements PROVIDER=aws only"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required for verify-live"
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "No reachable cluster. This target is NOT PROVED without kubeconfig."
  echo "Configure kubectl against the $ENVIRONMENT EKS cluster and retry."
  exit 1
fi

echo "cluster: $(kubectl config current-context)"
echo "waiting for $SERVICE in $NAMESPACE"
kubectl --namespace "$NAMESPACE" wait --for=condition=available --timeout=180s "deployment/$SERVICE"

ready="$(kubectl --namespace "$NAMESPACE" get deploy "$SERVICE" -o jsonpath='{.status.readyReplicas}')"
desired="$(kubectl --namespace "$NAMESPACE" get deploy "$SERVICE" -o jsonpath='{.status.replicas}')"
echo "readyReplicas=$ready desired=$desired"
if [[ -z "$ready" || "$ready" == "0" ]]; then
  echo "deployment has no ready replicas"
  exit 1
fi

echo "sending a request from an in-cluster probe pod"
kubectl apply -f "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/resilience/failure-lab/fixtures/probe-pod.yaml" >/dev/null
kubectl --namespace "$NAMESPACE" wait --for=condition=Ready --timeout=90s pod/sample-service-probe
body="$(kubectl --namespace "$NAMESPACE" exec sample-service-probe -- wget -qO- --timeout=10 "http://${SERVICE}:8080/" || true)"
kubectl --namespace "$NAMESPACE" delete pod sample-service-probe --ignore-not-found >/dev/null

if [[ "$body" != *"$EXPECTED"* ]]; then
  echo "unexpected response: $body"
  echo "expected to contain: $EXPECTED"
  echo "EKS ACTIVE / Argo CD Synced is not sufficient proof."
  exit 1
fi

echo "application response: $body"
echo "verify-live OK ($PROVIDER $ENVIRONMENT)"
