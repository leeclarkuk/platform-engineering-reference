#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail=0

if command -v terraform >/dev/null 2>&1; then
  terraform fmt -check -recursive terraform landing-zones || fail=1
else
  echo "terraform not installed; skip fmt check"
fi

if command -v gofmt >/dev/null 2>&1; then
  unformatted="$(gofmt -l examples/sample-service developer-platform/cli || true)"
  if [[ -n "$unformatted" ]]; then
    echo "gofmt needed on:"
    echo "$unformatted"
    fail=1
  fi
fi

if command -v yamllint >/dev/null 2>&1; then
  yamllint -c .yamllint.yml . || fail=1
fi

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  markdownlint-cli2 "**/*.md" "#.git" || fail=1
elif command -v npx >/dev/null 2>&1; then
  npx --yes markdownlint-cli2 "**/*.md" "#.git" "#**/node_modules" || fail=1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x scripts/*.sh scripts/aws/*.sh scripts/failure-lab/*.sh || fail=1
fi

if command -v helm >/dev/null 2>&1; then
  helm lint examples/sample-service/deploy/helm/sample-service || fail=1
fi

exit "$fail"
