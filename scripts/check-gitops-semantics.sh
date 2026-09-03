#!/usr/bin/env bash
# Field-level GitOps semantic checks plus committed negative fixtures.
# Parses YAML. Does not apply, kubectl, or talk to a cluster.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v go >/dev/null 2>&1; then
  printf 'FAIL check-gitops-semantics: go is required\n' >&2
  exit 1
fi

exec go run "$root/scripts/check-gitops-semantics.go" "$@"
