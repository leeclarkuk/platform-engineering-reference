#!/usr/bin/env bash
# CI-executed Pod Identity IAM trust contract check (Milestone 2).
# Provider-independent. No terraform plan/apply. No AWS API.
#
# Positive: the JSON file loaded by infra/aws/workload must match independent
# constants in scripts/check-pod-identity-trust.py.
# Negative: fixture policies with the wrong principal or missing TagSession
# must fail that same checker.
#
# This is the semantic assertion. Terraform validate does not evaluate
# lifecycle preconditions and is not claimed as this control.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
checker="${root}/scripts/check-pod-identity-trust.py"
workload_tf="${root}/infra/aws/workload/main.tf"
good_policy="${root}/infra/aws/workload/pod-identity-trust-policy.json"
wrong_principal="${root}/infra/aws/fixtures/pod-identity-trust-wrong-principal.json"
missing_tag="${root}/infra/aws/fixtures/pod-identity-trust-missing-tagsession.json"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'ERROR: python3 is required for pod-identity trust check (fail closed)\n' >&2
  exit 2
fi

for f in "$checker" "$workload_tf" "$good_policy" "$wrong_principal" "$missing_tag"; do
  if [[ ! -f "$f" ]]; then
    printf 'ERROR: missing %s\n' "$f" >&2
    exit 2
  fi
done

if ! grep -Fq 'assume_role_policy = file("${path.module}/pod-identity-trust-policy.json")' "$workload_tf"; then
  printf 'FAIL: workload main.tf must set pod identity assume_role_policy from pod-identity-trust-policy.json\n' >&2
  exit 1
fi
if grep -Fq 'sts:AssumeRoleWithWebIdentity' "$workload_tf" "$good_policy"; then
  printf 'FAIL: sts:AssumeRoleWithWebIdentity must not appear in the workload trust source\n' >&2
  exit 1
fi

set +e
good_out="$(python3 "$checker" --policy "$good_policy" 2>&1)"
good_code=$?
set -e
printf '%s\n' "$good_out"
if [[ "$good_code" -ne 0 ]]; then
  printf 'FAIL: real workload trust policy must exit 0 (got %s)\n' "$good_code" >&2
  exit 1
fi
printf 'ok positive pod-identity trust (exit %s)\n' "$good_code"

assert_nonzero() {
  local desc="$1"
  local path="$2"
  local out code
  set +e
  out="$(python3 "$checker" --policy "$path" 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
  if [[ "$code" -eq 0 ]]; then
    printf 'FAIL %s: wanted non-zero, got 0\n' "$desc" >&2
    exit 1
  fi
  if [[ "$code" -eq 2 ]]; then
    printf 'FAIL %s: usage/parse error (exit 2) is not a contract rejection\n' "$desc" >&2
    exit 1
  fi
  printf 'ok %s (exit %s)\n' "$desc" "$code"
}

assert_nonzero 'wrong Principal.Service ec2.amazonaws.com' "$wrong_principal"
assert_nonzero 'missing sts:TagSession' "$missing_tag"

printf 'ok: pod-identity trust semantic check (CI-executed, independent constants)\n'
exit 0
