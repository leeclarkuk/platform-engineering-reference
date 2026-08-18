#!/usr/bin/env bash
# Prove that policy-as-code rejects a known-bad fixture.
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

echo "expecting Checkov failure on insecure fixture"
set +e
checkov -d "$work/insecure" --framework terraform --compact --quiet \
  --config-file "$proof_config" --hard-fail-on CKV_AWS_20
insecure_status=$?
set -e

if [[ "$insecure_status" -eq 0 ]]; then
  echo "FAIL: insecure fixture was accepted. Policy enforcement is not working."
  exit 1
fi

echo "insecure fixture was rejected (exit $insecure_status)"

echo "expecting Checkov to pass public-access checks on secure fixture"
checkov -d "$work/secure" --framework terraform --compact --quiet \
  --config-file "$proof_config" \
  --check CKV_AWS_53,CKV_AWS_54,CKV_AWS_55,CKV_AWS_56

echo "policy enforcement proof OK"
