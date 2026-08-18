#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required for validate"
  exit 1
fi

roots=(
  terraform/aws
  terraform/azure
  terraform/gcp
  landing-zones/aws
)

for dir in "${roots[@]}"; do
  echo "validating $dir"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  terraform -chdir="$dir" validate
done

if command -v helm >/dev/null 2>&1; then
  helm lint examples/sample-service/deploy/helm/sample-service
  helm template sample-service examples/sample-service/deploy/helm/sample-service >/dev/null
fi

echo "validate OK"
