#!/usr/bin/env bash
# Verify .friction/pin.yml against go mod download -json, then install.
# Fail closed. Do not curl the sum database as proof. Do not run journeys.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pin="$root/.friction/pin.yml"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if ! command -v go >/dev/null 2>&1; then
  fail "go toolchain is required for pin verify (fail closed)"
fi
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required to parse go mod download JSON (fail closed)"
fi
if [[ ! -f "$pin" ]]; then
  fail "missing $pin"
fi

pin_get() {
  local key="$1"
  awk -F ': ' -v k="$key" '
    $1 == k {
      val = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      gsub(/^["'\'']|["'\'']$/, "", val)
      print val
      exit
    }
  ' "$pin"
}

version="$(pin_get version)"
commit="$(pin_get commit)"
binary_version="$(pin_get binary_version)"
want_sum="$(pin_get sum)"
want_gomod="$(pin_get gomod_sum)"
journeys="$(pin_get journeys_proved)"

[[ "$version" == "v0.1.0" ]] || fail "pin version must be v0.1.0 (got ${version:-empty})"
[[ "$commit" == "79398cfb55bcc253045bb0065a342a8fe805549a" ]] || fail "pin commit mismatch"
[[ "$binary_version" == "0.1.0" ]] || fail "pin binary_version must be 0.1.0 (got ${binary_version:-empty})"
[[ -n "$want_sum" && -n "$want_gomod" ]] || fail "pin sum/gomod_sum missing"
[[ "$journeys" == "false" ]] || fail "journeys_proved must be false in Milestone 0"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

cd "$tmpdir"
go mod init pinverify >/dev/null
export GOSUMDB=sum.golang.org

json="$(go mod download -json github.com/leeclarkuk/frictionctl@v0.1.0)" || fail "go mod download failed"

sums_file="$(mktemp)"
printf '%s\n' "$json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
err = d.get("Error") or ""
if err:
    print(err, file=sys.stderr)
    sys.exit(1)
print(d.get("Sum") or "")
print(d.get("GoModSum") or "")
' > "$sums_file" || fail "go mod download reported an Error or JSON could not be parsed"

mapfile -t sums < "$sums_file"
rm -f "$sums_file"
got_sum="${sums[0]:-}"
got_gomod="${sums[1]:-}"
if [[ -z "$got_sum" || -z "$got_gomod" ]]; then
  fail "toolchain did not return Sum and GoModSum (fail closed)"
fi

printf 'go version: %s\n' "$(go version)"
printf 'module tag: %s\n' "$version"
printf 'recorded sum: %s\n' "$want_sum"
printf 'toolchain Sum: %s\n' "$got_sum"
printf 'recorded gomod_sum: %s\n' "$want_gomod"
printf 'toolchain GoModSum: %s\n' "$got_gomod"

if [[ "$got_sum" != "$want_sum" || "$got_gomod" != "$want_gomod" ]]; then
  printf 'ERROR: Sum/GoModSum mismatch. Stopping. Will not install or invent new hashes.\n' >&2
  printf 'recorded sum=%s\n' "$want_sum" >&2
  printf 'toolchain Sum=%s\n' "$got_sum" >&2
  printf 'recorded gomod_sum=%s\n' "$want_gomod" >&2
  printf 'toolchain GoModSum=%s\n' "$got_gomod" >&2
  exit 1
fi

export PATH="$(go env GOPATH)/bin:${PATH}"
go install github.com/leeclarkuk/frictionctl/cmd/frictionctl@v0.1.0

got_bin="$(frictionctl version)"
printf 'frictionctl version: %s\n' "$got_bin"
if [[ "$got_bin" != "$binary_version" ]]; then
  fail "frictionctl version exact match failed: got '${got_bin}', want '${binary_version}'"
fi

printf 'ok: frictionctl pin verified (journeys not run)\n'
