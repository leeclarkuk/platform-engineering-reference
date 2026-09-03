#!/usr/bin/env bash
# Offline GitOps render, local-schema kubeconform, and semantic boundary checks.
# Tool installation may use the network. Validation does not configure remote
# schema URLs and does not apply, kubectl, helm install, or mutate Argo CD.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

pins="$root/gitops/GITOPS_PINS.md"
k8s_schema_dir="$root/gitops/schemas/kubernetes"
argo_schema_dir="$root/gitops/schemas/argocd"
cache_dir="$root/.cache/gitops-tools"

fail() {
  printf 'FAIL gitops-validate: %s\n' "$*" >&2
  exit 1
}

pin_get() {
  local key="$1"
  awk -F ': ' -v k="$key" '
    $1 == k {
      val = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ' "$pins"
}

assert_schema_dir() {
  local dir="$1"
  local label="$2"
  [[ -d "$dir" ]] || fail "missing schema directory ${dir}"
  local count
  count="$(find "$dir" -type f -name '*.json' | wc -l | tr -d ' ')"
  [[ "$count" -ge 1 ]] || fail "schema directory empty (${label}): ${dir}"
  printf 'ok schema dir %s (%s json files)\n' "$label" "$count"
}

[[ -f "$pins" ]] || fail "missing ${pins}"

assert_schema_dir "$k8s_schema_dir" "kubernetes"
assert_schema_dir "$argo_schema_dir" "argocd"

kustomize_version="$(pin_get kustomize_version)"
kustomize_archive="$(pin_get kustomize_archive)"
kustomize_archive_url="$(pin_get kustomize_archive_url)"
kustomize_archive_sha256="$(pin_get kustomize_archive_sha256)"
kustomize_binary_sha256="$(pin_get kustomize_binary_sha256_linux_amd64)"
kubeconform_version="$(pin_get kubeconform_version)"
kubeconform_archive="$(pin_get kubeconform_archive)"
kubeconform_archive_url="$(pin_get kubeconform_archive_url)"
kubeconform_archive_sha256="$(pin_get kubeconform_archive_sha256)"
kubeconform_binary_sha256="$(pin_get kubeconform_binary_sha256_linux_amd64)"
k8s_version="$(pin_get kubernetes_schema_version)"

[[ -n "$kustomize_version" && -n "$kustomize_archive_sha256" ]] || fail "kustomize pins missing"
[[ -n "$kubeconform_version" && -n "$kubeconform_archive_sha256" ]] || fail "kubeconform pins missing"
[[ -n "$k8s_version" ]] || fail "kubernetes_schema_version pin missing"

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

install_pinned_binary() {
  local name="$1"
  local archive="$2"
  local url="$3"
  local archive_sha="$4"
  local binary_sha="$5"
  local version_flag="$6"
  local want_version="$7"
  mkdir -p "$cache_dir"
  local dest="$cache_dir/$name"
  if [[ -x "$dest" ]]; then
    local got_bin
    got_bin="$(sha256_file "$dest")"
    if [[ "$got_bin" == "$binary_sha" ]]; then
      printf 'ok cached %s sha256 %s\n' "$name" "$got_bin"
      return 0
    fi
    printf 'cached %s hash mismatch; reinstalling\n' "$name"
    rm -f "$dest"
  fi
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    curl -fsSL -o "$archive" "$url"
    got="$(sha256_file "$archive")"
    if [[ "$got" != "$archive_sha" ]]; then
      printf 'FAIL %s archive sha256 mismatch: got %s want %s\n' "$name" "$got" "$archive_sha" >&2
      exit 1
    fi
    tar -xzf "$archive" "$name"
    got_bin="$(sha256_file "$name")"
    if [[ "$got_bin" != "$binary_sha" ]]; then
      printf 'FAIL %s binary sha256 mismatch: got %s want %s\n' "$name" "$got_bin" "$binary_sha" >&2
      exit 1
    fi
    install -m 0755 "$name" "$dest"
  )
  rm -rf "$tmp"
  printf 'ok installed %s from pinned archive\n' "$name"
}

install_pinned_binary kustomize "$kustomize_archive" "$kustomize_archive_url" \
  "$kustomize_archive_sha256" "$kustomize_binary_sha256" version "v${kustomize_version}"
install_pinned_binary kubeconform "$kubeconform_archive" "$kubeconform_archive_url" \
  "$kubeconform_archive_sha256" "$kubeconform_binary_sha256" -v "v${kubeconform_version}"

export PATH="$cache_dir:$PATH"

got_kustomize="$(kustomize version)"
[[ "$got_kustomize" == "v${kustomize_version}" ]] || fail "kustomize version ${got_kustomize} != v${kustomize_version}"
got_kubeconform="$(kubeconform -v)"
[[ "$got_kubeconform" == "v${kubeconform_version}" ]] || fail "kubeconform version ${got_kubeconform} != v${kubeconform_version}"
printf 'ok kustomize %s\n' "$got_kustomize"
printf 'ok kubeconform %s\n' "$got_kubeconform"

schema_k8s="${k8s_schema_dir}/{{ .NormalizedKubernetesVersion }}-standalone{{ .StrictSuffix }}/{{ .ResourceKind }}{{ .KindSuffix }}.json"
schema_argo="${argo_schema_dir}/{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json"

# Fail closed: schema locations are local paths under gitops/schemas/ only.
# Do not pass -schema-location default, http(s) URLs, or -ignore-missing-schemas.
for loc in "$schema_k8s" "$schema_argo"; do
  case "$loc" in
    http://*|https://*|default|*/default)
      fail "remote schema location is forbidden: ${loc}"
      ;;
  esac
  [[ "$loc" == "$root/gitops/schemas/"* ]] || fail "schema location escapes gitops/schemas/: ${loc}"
done

render_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$render_dir"
}
trap cleanup EXIT

kustomize build "$root/gitops" > "$render_dir/gitops.yaml"
kustomize build "$root/gitops/apps" > "$render_dir/apps.yaml"
[[ -s "$render_dir/gitops.yaml" ]] || fail "kustomize build gitops produced no YAML"
printf 'ok kustomize build gitops (%s bytes)\n' "$(wc -c < "$render_dir/gitops.yaml" | tr -d ' ')"
if [[ -s "$render_dir/apps.yaml" ]]; then
  printf 'ok kustomize build gitops/apps (%s bytes)\n' "$(wc -c < "$render_dir/apps.yaml" | tr -d ' ')"
else
  printf 'ok kustomize build gitops/apps (empty render; no M4 Application)\n'
fi

run_kubeconform() {
  local file="$1"
  kubeconform \
    -strict \
    -summary \
    -kubernetes-version "$k8s_version" \
    -schema-location "$schema_k8s" \
    -schema-location "$schema_argo" \
    "$file"
}

run_kubeconform "$render_dir/gitops.yaml"
if [[ -s "$render_dir/apps.yaml" ]]; then
  run_kubeconform "$render_dir/apps.yaml"
fi

"$root/scripts/check-gitops-semantics.sh"

printf 'ok gitops-validate (local schemas only; no cluster; no apply)\n'
