#!/usr/bin/env bash
# Field-level ObservabilityContract semantic checks.
# Parses YAML. Does not start a collector, Prometheus, or a cluster.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v go >/dev/null 2>&1; then
  printf 'FAIL check-observability-semantics: go is required\n' >&2
  exit 1
fi

exec go run "$root/scripts/observability-semantics" "$@"
