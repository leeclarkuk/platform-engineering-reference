#!/usr/bin/env bash
# Detect runnable cloud-mutation commands in executable paths only.
# Scans .github/workflows/, Makefile, and scripts/. Ignores comment-only lines.
# Does not scan README, AGENTS.md, or ADRs.

set -euo pipefail

tf="terraform"
tof="tofu"
kc="kubectl"
hm="helm"
ap="apply"
ds="destroy"
ins="install"
up="upgrade"

fail=0
paths=(.github/workflows Makefile scripts)

while IFS= read -r -d '' f; do
  if [[ ! -f "$f" ]]; then
    continue
  fi
  # Build patterns at runtime so this file does not contain the command text.
  hits="$(sed -E '/^[[:space:]]*#/d' "$f" | grep -E -n \
    -e "${tf}[[:space:]]+(${ap}|${ds})" \
    -e "${tof}[[:space:]]+(${ap}|${ds})" \
    -e "${kc}[[:space:]]+${ap}" \
    -e "${hm}[[:space:]]+(${ins}|${up})" || true)"
  if [[ -n "$hits" ]]; then
    printf 'FAIL runnable cloud-mutation command in %s\n' "$f" >&2
    printf '%s\n' "$hits" >&2
    fail=1
  fi
done < <(find "${paths[@]}" -type f -print0)

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

printf 'ok: no cloud-mutation commands in workflows/Make/scripts\n'
exit 0
