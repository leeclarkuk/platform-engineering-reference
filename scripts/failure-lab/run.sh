#!/usr/bin/env bash
set -euo pipefail

TEST="${TEST:-pod-delete}"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$TEST" in
  pod-delete) "$dir/pod-delete.sh" ;;
  bad-deployment) "$dir/bad-deployment.sh" ;;
  network-policy) "$dir/network-policy.sh" ;;
  node-loss) "$dir/node-loss.sh" ;;
  *)
    echo "Unknown TEST=$TEST (pod-delete|bad-deployment|network-policy|node-loss)"
    exit 1
    ;;
esac
