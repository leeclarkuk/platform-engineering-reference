#!/usr/bin/env bash
# Install Argo CD from upstream, then apply this repository's bootstrap.
# Requires kubectl against the target cluster. Does not apply application
# workloads; Argo CD does that from Git.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARGO_VERSION="${ARGO_VERSION:-v2.13.3}"
NAMESPACE="${NAMESPACE:-argocd}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required"
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "No reachable cluster. Refusing to pretend Argo CD is installed."
  exit 1
fi

kubectl apply -f "$root/gitops/bootstrap/namespace.yaml"
kubectl apply -n "$NAMESPACE" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_VERSION}/manifests/install.yaml"
kubectl apply -f "$root/gitops/argocd/project.yaml"
kubectl apply -f "$root/gitops/bootstrap/root-app.yaml"

echo "Argo CD bootstrap applied. Wait for the repo-server and application-controller to become ready,"
echo "then confirm the sample-service Application is Synced and that verify-live still passes."
