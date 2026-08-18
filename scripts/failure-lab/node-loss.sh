#!/usr/bin/env bash
# Experiment 4: node loss.
# Default: cordon and drain one node. That reschedules pods without
# terminating an EC2 instance.
# AWS instance termination requires CONFIRM=yes AWS_TERMINATE=yes.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CONFIRM="${CONFIRM:-}"
AWS_TERMINATE="${AWS_TERMINATE:-}"

require_kubectl

node="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$node" ]]; then
  echo "no nodes found"
  exit 1
fi

echo "== node-loss: target $node"
body="$(request_ok || true)"
if [[ "$body" != *"ok"* ]]; then
  echo "baseline request failed: $body"
  exit 1
fi

if [[ "$AWS_TERMINATE" == "yes" ]]; then
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Refusing to terminate an EC2 instance. Re-run with CONFIRM=yes AWS_TERMINATE=yes"
    exit 1
  fi
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is required for AWS_TERMINATE=yes"
    exit 1
  fi
  instance="$(kubectl get node "$node" -o jsonpath='{.spec.providerID}' | awk -F/ '{print $NF}')"
  echo "terminating instance $instance (destructive)"
  aws ec2 terminate-instances --instance-ids "$instance" >/dev/null
else
  echo "cordon and drain $node (non-destructive default)"
  kubectl cordon "$node"
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=180s
fi

echo "waiting for the service to be available elsewhere"
kubectl --namespace "$NAMESPACE" wait --for=condition=available --timeout=300s "deployment/$SERVICE"
after="$(request_ok || true)"

if [[ "$AWS_TERMINATE" != "yes" ]]; then
  kubectl uncordon "$node" || true
fi

if [[ "$after" != *"ok"* ]]; then
  echo "service did not recover after node loss: $after"
  exit 1
fi

echo "pods rescheduled and GET / returned ok"
echo "node-loss OK"
