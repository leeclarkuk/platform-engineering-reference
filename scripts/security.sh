#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if command -v checkov >/dev/null 2>&1; then
  checkov -d terraform --config-file .checkov.yaml
else
  echo "checkov not installed; skip live tree scan"
fi

if command -v trivy >/dev/null 2>&1; then
  trivy fs --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 .
else
  echo "trivy not installed; skip filesystem scan"
fi

scripts/test-policy.sh
