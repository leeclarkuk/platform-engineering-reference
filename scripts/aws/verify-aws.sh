#!/usr/bin/env bash
# Every AWS check that can run without cloud credentials.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

fail=0

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required for verify-aws"
  exit 1
fi

echo "== terraform fmt"
terraform fmt -check -recursive terraform/aws terraform/modules/aws landing-zones/aws || fail=1

stacks=(
  terraform/aws/bootstrap
  terraform/aws/network
  terraform/aws/workload
  landing-zones/aws
)

for dir in "${stacks[@]}"; do
  echo "== terraform validate $dir"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  terraform -chdir="$dir" validate || fail=1
done

echo "== terraform test (modules)"
terraform -chdir=terraform/modules/aws/transit-gateway test || fail=1
terraform -chdir=terraform/modules/aws/vpc test || fail=1

if command -v tflint >/dev/null 2>&1; then
  echo "== tflint"
  tflint --init >/dev/null
  tflint --chdir terraform/aws --recursive || fail=1
  tflint --chdir terraform/modules/aws --recursive || fail=1
else
  echo "tflint not installed; skip"
fi

echo "== route assertions"
"$root/scripts/aws/assert-routes.sh" || fail=1

if command -v helm >/dev/null 2>&1; then
  echo "== helm lint"
  helm lint examples/sample-service/deploy/helm/sample-service || fail=1
  helm template sample-service examples/sample-service/deploy/helm/sample-service \
    --namespace sample-service >/tmp/sample-service-manifests.yaml || fail=1
else
  echo "helm not installed; skip"
fi

if command -v kubeconform >/dev/null 2>&1; then
  echo "== kubeconform"
  kubeconform -strict -ignore-missing-schemas \
    kubernetes/base kubernetes/eks gitops/bootstrap gitops/argocd gitops/platform \
    gitops/applications resilience/failure-lab/fixtures || fail=1
  if [[ -f /tmp/sample-service-manifests.yaml ]]; then
    kubeconform -strict -ignore-missing-schemas /tmp/sample-service-manifests.yaml || fail=1
  fi
else
  echo "kubeconform not installed; skip"
fi

echo "== failure-lab syntax"
for f in "$root"/scripts/failure-lab/*.sh "$root"/scripts/aws/*.sh; do
  bash -n "$f" || fail=1
done

if [[ "$fail" -ne 0 ]]; then
  echo "verify-aws failed"
  exit 1
fi
echo "verify-aws OK"
