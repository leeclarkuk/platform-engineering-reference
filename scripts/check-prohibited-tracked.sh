#!/usr/bin/env bash
# Reject tracked paths that match the Milestone 0 denylist.
# Default input: git ls-files -z.
# Test input: --stdin0 (NUL-separated paths on stdin; does not create files).
# Exit 0: no prohibited paths.
# Exit 1: one or more prohibited paths (prints PROHIBITED: <path>).
# Exit 2: usage or unexpected tool error (must not be treated as a denylist hit).

set -euo pipefail

usage() {
  printf 'ERROR: usage: %s [--stdin0]\n' "${0##*/}" >&2
  exit 2
}

if [[ $# -gt 1 ]]; then
  usage
fi

mode=git
if [[ $# -eq 1 ]]; then
  if [[ "$1" != "--stdin0" ]]; then
    usage
  fi
  mode=stdin0
fi

is_prohibited() {
  local path="$1"
  local base="${path##*/}"

  # Directory component .terraform/ (nested paths included).
  if [[ "$path" == .terraform/* || "$path" == */.terraform/* || "$path" == .terraform ]]; then
    return 0
  fi

  case "$base" in
    *.tfstate|*.tfstate.*)
      return 0
      ;;
    *.pem|*.key)
      return 0
      ;;
    id_rsa|id_ed25519)
      return 0
      ;;
    kubeconfig)
      return 0
      ;;
    credentials|credentials.*)
      return 0
      ;;
    .env)
      return 0
      ;;
    *.tfvars)
      if [[ "$base" != *.example ]]; then
        return 0
      fi
      ;;
  esac
  return 1
}

list="$(mktemp)"
trap 'rm -f "$list"' EXIT

if [[ "$mode" == "stdin0" ]]; then
  cat > "$list" || {
    printf 'ERROR: failed to read stdin\n' >&2
    exit 2
  }
else
  if ! git ls-files -z > "$list"; then
    printf 'ERROR: git ls-files failed\n' >&2
    exit 2
  fi
fi

found=0
path=""
while IFS= read -r -d '' path || [[ -n "${path:-}" ]]; do
  if [[ -z "$path" ]]; then
    continue
  fi
  if is_prohibited "$path"; then
    printf 'PROHIBITED: %s\n' "$path"
    found=1
  fi
done < "$list"

if [[ "$found" -ne 0 ]]; then
  exit 1
fi

printf 'ok: no prohibited tracked paths\n'
exit 0
