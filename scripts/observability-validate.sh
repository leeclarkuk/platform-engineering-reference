#!/usr/bin/env bash
# Offline ObservabilityContract schema, collector config, Prometheus rules,
# pin, and semantic checks. Tool installation may use the network.
# Validation does not start the collector, start Prometheus, open listeners,
# apply, kubectl, helm install, or contact a cluster, Argo CD, AWS, or a
# remote schema service.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
unset AWS_DEFAULT_REGION AWS_REGION AWS_SHARED_CREDENTIALS_FILE
unset KUBECONFIG
export KUBECONFIG=/dev/null

pins="$root/observability/OBSERVABILITY_PINS.md"
cache_dir="$root/.cache/observability-tools"
m5_neg="$root/testdata/observability-m5-negatives"

fail() {
  printf 'FAIL observability-validate: %s\n' "$*" >&2
  exit 1
}

pin_get_from() {
  local pins_file="$1"
  local key="$2"
  awk -F ': ' -v k="$key" '
    $1 == k {
      val = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ' "$pins_file"
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

pin_keys=(
  otelcol_contrib_version
  otelcol_contrib_archive
  otelcol_contrib_archive_url
  otelcol_contrib_archive_sha256
  otelcol_contrib_binary_sha256_linux_amd64
  promtool_version
  promtool_archive
  promtool_archive_url
  promtool_archive_member
  promtool_archive_sha256
  promtool_binary_sha256_linux_amd64
  observabilitycontract_schema_path
  observabilitycontract_schema_sha256
)

verify_committed_pins() {
  local pins_file="$1"
  local repo_root="$2"
  if [[ ! -f "$pins_file" ]]; then
    printf 'FAIL missing pin file %s\n' "$pins_file" >&2
    return 1
  fi
  local key
  for key in "${pin_keys[@]}"; do
    if [[ -z "$(pin_get_from "$pins_file" "$key")" ]]; then
      printf 'FAIL pin file missing key %s: %s\n' "$key" "$pins_file" >&2
      return 1
    fi
  done
  local rel sha f got
  rel="$(pin_get_from "$pins_file" observabilitycontract_schema_path)"
  sha="$(pin_get_from "$pins_file" observabilitycontract_schema_sha256)"
  case "$rel" in
    observability/schemas/*) ;;
    *)
      printf 'FAIL schema path escapes observability/schemas/: %s\n' "$rel" >&2
      return 1
      ;;
  esac
  f="${repo_root}/${rel}"
  if [[ ! -f "$f" ]]; then
    printf 'FAIL missing required schema %s\n' "$rel" >&2
    return 1
  fi
  got="$(sha256_file "$f")"
  if [[ "$got" != "$sha" ]]; then
    printf 'FAIL schema hash mismatch %s: got %s want %s\n' "$rel" "$got" "$sha" >&2
    return 1
  fi
  return 0
}

assert_nonzero() {
  local desc="$1"
  local needle="$2"
  shift 2
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
  printf '%s\n' "$out" | grep -Eq "$needle" || {
    printf 'FAIL %s: non-zero without intended reason %s\n%s\n' "$desc" "$needle" "$out" >&2
    exit 1
  }
  printf 'ok named negative %s (exit %s)\n' "$desc" "$code"
}

check_no_live_start() {
  local base="${1:-.}"
  local paths=()
  [[ -d "$base/.github/workflows" ]] && paths+=("$base/.github/workflows")
  [[ -e "$base/Makefile" ]] && paths+=("$base/Makefile")
  [[ -d "$base/scripts" ]] && paths+=("$base/scripts")
  if [[ "${#paths[@]}" -eq 0 ]]; then
    printf 'FAIL no scannable workflows/Make/scripts under %s\n' "$base" >&2
    return 1
  fi
  local fail_start=0
  local f hits
  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue
    hits="$(sed -E '/^[[:space:]]*#/d' "$f" | grep -E -n \
      -e 'otelcol-contrib[[:space:]]+--config' \
      -e 'otelcol-contrib[[:space:]]+run([[:space:]]|$)' \
      -e '(^|[[:space:]])prometheus[[:space:]]+--config' \
      -e '(^|[[:space:]])prometheus[[:space:]]+--web' \
      || true)"
    if [[ -n "$hits" ]]; then
      printf 'FAIL live start of collector or Prometheus in %s\n' "$f" >&2
      printf '%s\n' "$hits" >&2
      fail_start=1
    fi
  done < <(find "${paths[@]}" -type f -print0)
  if [[ "$fail_start" -ne 0 ]]; then
    return 1
  fi
  printf 'ok: no collector/Prometheus live start in workflows/Make/scripts\n'
  return 0
}

[[ -f "$pins" ]] || fail "missing ${pins}"

if ! verify_committed_pins "$pins" "$root"; then
  fail "committed pin or schema SHA-256 check failed"
fi
printf 'ok committed observability pins and schema SHA-256\n'

otel_version="$(pin_get_from "$pins" otelcol_contrib_version)"
otel_archive="$(pin_get_from "$pins" otelcol_contrib_archive)"
otel_url="$(pin_get_from "$pins" otelcol_contrib_archive_url)"
otel_archive_sha="$(pin_get_from "$pins" otelcol_contrib_archive_sha256)"
otel_bin_sha="$(pin_get_from "$pins" otelcol_contrib_binary_sha256_linux_amd64)"
prom_version="$(pin_get_from "$pins" promtool_version)"
prom_archive="$(pin_get_from "$pins" promtool_archive)"
prom_url="$(pin_get_from "$pins" promtool_archive_url)"
prom_member="$(pin_get_from "$pins" promtool_archive_member)"
prom_archive_sha="$(pin_get_from "$pins" promtool_archive_sha256)"
prom_bin_sha="$(pin_get_from "$pins" promtool_binary_sha256_linux_amd64)"

[[ -n "$otel_version" && -n "$otel_archive_sha" && -n "$otel_bin_sha" ]] || fail "otelcol-contrib pins missing"
[[ -n "$prom_version" && -n "$prom_archive_sha" && -n "$prom_bin_sha" && -n "$prom_member" ]] || fail "promtool pins missing"

install_pinned_otelcol() {
  mkdir -p "$cache_dir"
  local dest="$cache_dir/otelcol-contrib"
  if [[ -x "$dest" ]]; then
    local got_bin
    got_bin="$(sha256_file "$dest")"
    if [[ "$got_bin" == "$otel_bin_sha" ]]; then
      printf 'ok cached otelcol-contrib sha256 %s\n' "$got_bin"
      return 0
    fi
    printf 'cached otelcol-contrib hash mismatch; reinstalling\n'
    rm -f "$dest"
  fi
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    curl -fsSL -o "$otel_archive" "$otel_url"
    got="$(sha256_file "$otel_archive")"
    if [[ "$got" != "$otel_archive_sha" ]]; then
      printf 'FAIL otelcol-contrib archive sha256 mismatch: got %s want %s\n' "$got" "$otel_archive_sha" >&2
      exit 1
    fi
    tar --no-same-owner -xzf "$otel_archive" otelcol-contrib
    got_bin="$(sha256_file otelcol-contrib)"
    if [[ "$got_bin" != "$otel_bin_sha" ]]; then
      printf 'FAIL otelcol-contrib binary sha256 mismatch: got %s want %s\n' "$got_bin" "$otel_bin_sha" >&2
      exit 1
    fi
    install -m 0755 otelcol-contrib "$dest"
  )
  rm -rf "$tmp"
  printf 'ok installed otelcol-contrib from pinned archive\n'
}

install_pinned_promtool() {
  mkdir -p "$cache_dir"
  local dest="$cache_dir/promtool"
  if [[ -x "$dest" ]]; then
    local got_bin
    got_bin="$(sha256_file "$dest")"
    if [[ "$got_bin" == "$prom_bin_sha" ]]; then
      printf 'ok cached promtool sha256 %s\n' "$got_bin"
      return 0
    fi
    printf 'cached promtool hash mismatch; reinstalling\n'
    rm -f "$dest"
  fi
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    curl -fsSL -o "$prom_archive" "$prom_url"
    got="$(sha256_file "$prom_archive")"
    if [[ "$got" != "$prom_archive_sha" ]]; then
      printf 'FAIL promtool archive sha256 mismatch: got %s want %s\n' "$got" "$prom_archive_sha" >&2
      exit 1
    fi
    tar --no-same-owner -xzf "$prom_archive" "$prom_member"
    got_bin="$(sha256_file "$prom_member")"
    if [[ "$got_bin" != "$prom_bin_sha" ]]; then
      printf 'FAIL promtool binary sha256 mismatch: got %s want %s\n' "$got_bin" "$prom_bin_sha" >&2
      exit 1
    fi
    install -m 0755 "$prom_member" "$dest"
  )
  rm -rf "$tmp"
  printf 'ok installed promtool from pinned archive\n'
}

install_pinned_otelcol
install_pinned_promtool
export PATH="$cache_dir:$PATH"

got_otel="$(otelcol-contrib version 2>/dev/null | awk '{print $3}')"
[[ "$got_otel" == "$otel_version" ]] || fail "otelcol-contrib version ${got_otel} != ${otel_version}"
got_prom="$(promtool --version 2>/dev/null | awk '/promtool, version/{print $3}')"
[[ "$got_prom" == "$prom_version" ]] || fail "promtool version ${got_prom} != ${prom_version}"
printf 'ok otelcol-contrib %s\n' "$got_otel"
printf 'ok promtool %s\n' "$got_prom"

chmod +x "$root/scripts/check-observability-semantics.sh"

validate_tree() {
  local tree="$1"
  local pins_file="${tree}/observability/OBSERVABILITY_PINS.md"
  verify_committed_pins "$pins_file" "$tree" || return 1
  "$root/scripts/check-observability-semantics.sh" --repo-root "$root" --tree "$tree" || return 1
  local cfg="${tree}/observability/otel/collector-metrics.yaml"
  local rules="${tree}/observability/prometheus/rules/sample.yml"
  if ! otelcol-contrib validate --config="file:${cfg}"; then
    printf 'FAIL invalid collector config: otelcol-contrib validate rejected %s\n' "$cfg" >&2
    return 1
  fi
  if ! promtool check rules "$rules"; then
    printf 'FAIL invalid Prometheus rules: promtool check rules rejected %s\n' "$rules" >&2
    return 1
  fi
  return 0
}

validate_tree "$root" || fail "live tree validation failed"
printf 'ok live observability tree (schema, semantics, otelcol validate, promtool check rules)\n'

check_no_live_start "$root" || fail "live start commands in validation path"
"$root/scripts/check-no-cloud-mutation.sh" || fail "cloud-mutation commands in validation path"

stage_overlay() {
  local fixture="$1"
  local dest="$2"
  mkdir -p "$dest"
  cp -a "$root/observability" "$dest/observability"
  if [[ -d "$fixture/observability" ]]; then
    cp -a "$fixture/observability/." "$dest/observability/"
  fi
}

run_overlay_negative() {
  local name="$1"
  local needle="$2"
  local fixture="${m5_neg}/${name}"
  [[ -d "$fixture" ]] || fail "missing named fixture ${fixture}"
  local tmp
  tmp="$(mktemp -d)"
  stage_overlay "$fixture" "$tmp"
  set +e
  local out code
  out="$(validate_tree "$tmp" 2>&1)"
  code=$?
  set -e
  rm -rf "$tmp"
  printf '%s\n' "$out"
  if [[ "$code" -eq 0 ]]; then
    printf 'FAIL %s: wanted non-zero, got 0\n' "$name" >&2
    exit 1
  fi
  printf '%s\n' "$out" | grep -Eq "$needle" || {
    printf 'FAIL %s: non-zero without intended reason %s\n%s\n' "$name" "$needle" "$out" >&2
    exit 1
  }
  printf 'ok named negative %s (exit %s)\n' "$name" "$code"
}

[[ -d "$m5_neg" ]] || fail "missing ${m5_neg}"

run_overlay_negative malformed-yaml 'malformed YAML'
run_overlay_negative wrong-apiversion-kind 'apiVersion'
run_overlay_negative unknown-fields 'unknown field'
run_overlay_negative name-drift 'identity name'
run_overlay_negative namespace-drift 'identity namespace'
run_overlay_negative owner-drift 'identity owner'
run_overlay_negative missing-otel-attrs 'missing OTel'
run_overlay_negative wildcard-or-empty-identity 'wildcard|empty identity'
run_overlay_negative high-cardinality-attrs 'high-cardinality'
run_overlay_negative cloud-vendor-exporter 'cloud/vendor exporter'
run_overlay_negative remote-write 'remote write'
run_overlay_negative embedded-secrets 'embedded secrets'
run_overlay_negative logs-pipeline 'logs pipeline'
run_overlay_negative traces-pipeline 'traces pipeline'
run_overlay_negative invalid-collector-config 'invalid collector'
run_overlay_negative invalid-prom-rules 'invalid Prometheus rules'
run_overlay_negative undeclared-metric 'undeclared metric'
run_overlay_negative wrong-job 'wrong job'
run_overlay_negative paging-critical-severity 'paging/critical'
run_overlay_negative invented-slo 'invented SLO'
run_overlay_negative k8s-resources-under-observability 'Kubernetes resource'
run_overlay_negative terraform-iam-under-observability 'Terraform|IAM'
run_overlay_negative missing-pin-or-schema 'missing pin file|missing key|missing required schema'
run_overlay_negative stale-hash 'hash mismatch'

[[ -d "$m5_neg/live-start-or-mutation-in-validation" ]] || fail "missing live-start fixture"
assert_nonzero 'live-start-or-mutation-in-validation' 'cloud-mutation|live start|kubectl' \
  "$root/scripts/check-no-cloud-mutation.sh" \
  "$m5_neg/live-start-or-mutation-in-validation"

assert_nonzero 'live-start-collector-or-prometheus' 'live start' \
  check_no_live_start "$m5_neg/live-start-or-mutation-in-validation"

printf 'ok observability-validate (no collector start; no cluster; no AWS)\n'
