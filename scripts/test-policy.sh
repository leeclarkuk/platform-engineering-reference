#!/usr/bin/env bash
# Prove that policy-as-code rejects known-bad fixtures.
# Scan copies in /tmp so the repo .checkov.yaml skip-path cannot hide them.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

insecure="$root/security/policy-as-code/fixtures/insecure"
secure="$root/security/policy-as-code/fixtures/secure"

if ! command -v checkov >/dev/null 2>&1; then
  echo "checkov is required to prove policy enforcement"
  exit 1
fi

proof_config="$root/security/policy-as-code/checkov.proof.yaml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/insecure" "$work/secure"
cp -a "$insecure/." "$work/insecure/"
cp -a "$secure/." "$work/secure/"

echo "expecting Checkov failure on public S3"
set +e
checkov -d "$work/insecure" --framework terraform --compact --quiet \
  --config-file "$proof_config" --hard-fail-on CKV_AWS_20
s3_status=$?
set -e
if [[ "$s3_status" -eq 0 ]]; then
  echo "FAIL: public S3 fixture was accepted."
  exit 1
fi
echo "public S3 fixture was rejected (exit $s3_status)"

echo "expecting Checkov failure on wildcard IAM"
set +e
checkov -d "$work/insecure" --framework terraform --compact --quiet \
  --config-file "$proof_config" --check CKV_AWS_62 --hard-fail-on CKV_AWS_62
iam_status=$?
set -e
if [[ "$iam_status" -eq 0 ]]; then
  echo "FAIL: wildcard IAM fixture was accepted."
  exit 1
fi
echo "wildcard IAM fixture was rejected (exit $iam_status)"

echo "expecting Checkov failure on public SSH security group"
set +e
checkov -d "$work/insecure" --framework terraform --compact --quiet \
  --config-file "$proof_config" --check CKV_AWS_24 --hard-fail-on CKV_AWS_24
sg_status=$?
set -e
if [[ "$sg_status" -eq 0 ]]; then
  echo "FAIL: public security group fixture was accepted."
  exit 1
fi
echo "public security group fixture was rejected (exit $sg_status)"

echo "expecting Checkov failure on privileged pod"
set +e
checkov -f "$work/insecure/privileged-pod.yaml" --framework kubernetes --compact --quiet \
  --config-file "$proof_config" --check CKV_K8S_16 --hard-fail-on CKV_K8S_16
k8s_status=$?
set -e
if [[ "$k8s_status" -eq 0 ]]; then
  echo "FAIL: privileged pod fixture was accepted."
  exit 1
fi
echo "privileged pod fixture was rejected (exit $k8s_status)"

echo "expecting Checkov to pass public-access checks on secure fixture"
checkov -d "$work/secure" --framework terraform --compact --quiet \
  --config-file "$proof_config" \
  --check CKV_AWS_53,CKV_AWS_54,CKV_AWS_55,CKV_AWS_56

echo "policy enforcement proof OK"
