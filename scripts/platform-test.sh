#!/usr/bin/env bash
# Run Go unit tests and platform CLI positive/negative checks.
# Does not call AWS. Does not run Terraform, GitOps apply, or journeys.

set -euo pipefail

assert_nonzero() {
  local desc="$1"
  shift
  local out code
  set +e
  out="$("$@" 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
  if [[ "$code" -eq 0 ]]; then
    printf 'FAIL %s: wanted non-zero, got 0\n' "$desc" >&2
    exit 1
  fi
  printf 'ok %s (exit %s)\n' "$desc" "$code"
}

go test ./...

env -u AWS_ACCESS_KEY_ID \
  -u AWS_SECRET_ACCESS_KEY \
  -u AWS_SESSION_TOKEN \
  -u AWS_PROFILE \
  go run ./cmd/platform doctor

go run ./cmd/platform validate testdata/workloadcontract-valid.yaml

assert_nonzero 'missing-field validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-missing-owner.yaml

assert_nonzero 'kustomize goldenPath validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-goldenpath-kustomize.yaml

assert_nonzero 'missing-file validate' \
  go run ./cmd/platform validate testdata/does-not-exist.yaml

assert_nonzero 'wrong apiVersion validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-apiversion.yaml

assert_nonzero 'wrong kind validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-kind.yaml

assert_nonzero 'DNS-1123 name validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-name-dns.yaml

assert_nonzero 'DNS-1123 serviceAccount.namespace validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-sa-namespace-dns.yaml

assert_nonzero 'DNS-1123 serviceAccount.name validate' \
  go run ./cmd/platform validate testdata/workloadcontract-invalid-sa-name-dns.yaml

parent="$(mktemp -d)"
dest="${parent}/widget"
go run ./cmd/platform create --name widget --owner platform --namespace apps --out-dir "$dest"
go run ./cmd/platform validate "${dest}/widget.yaml"
printf 'ok create-then-validate\n'

exist="$(mktemp -d)"
assert_nonzero 'create into existing DIR' \
  go run ./cmd/platform create --name widget --owner platform --namespace apps --out-dir "$exist"

demo_parent="$(mktemp -d)"
demo_dest="${demo_parent}/out"
assert_nonzero 'create invalid name Demo' \
  go run ./cmd/platform create --name Demo --owner platform --namespace apps --out-dir "$demo_dest"

ns_parent="$(mktemp -d)"
ns_dest="${ns_parent}/out"
assert_nonzero 'create invalid namespace Demo' \
  go run ./cmd/platform create --name widget --owner platform --namespace Demo --out-dir "$ns_dest"

printf 'ok platform-test\n'
