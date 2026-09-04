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

# Verify the three exact schema paths and recorded SHA-256 values.
# repo_root is the tree the pin paths are relative to. Prints FAIL to stderr
# and returns non-zero; does not exit the process (so negatives can use it).
verify_committed_schemas() {
  local pins_file="$1"
  local repo_root="$2"
  if [[ ! -f "$pins_file" ]]; then
    printf 'FAIL missing pin file %s\n' "$pins_file" >&2
    return 1
  fi
  local ns_path app_path proj_path ns_sha app_sha proj_sha
  ns_path="$(pin_get_from "$pins_file" kubernetes_namespace_schema_path)"
  app_path="$(pin_get_from "$pins_file" argocd_application_schema_path)"
  proj_path="$(pin_get_from "$pins_file" argocd_appproject_schema_path)"
  ns_sha="$(pin_get_from "$pins_file" kubernetes_namespace_schema_sha256)"
  app_sha="$(pin_get_from "$pins_file" argocd_application_schema_sha256)"
  proj_sha="$(pin_get_from "$pins_file" argocd_appproject_schema_sha256)"
  if [[ -z "$ns_path" || -z "$app_path" || -z "$proj_path" ]]; then
    printf 'FAIL pin file missing schema path keys: %s\n' "$pins_file" >&2
    return 1
  fi
  if [[ -z "$ns_sha" || -z "$app_sha" || -z "$proj_sha" ]]; then
    printf 'FAIL pin file missing schema sha256 keys: %s\n' "$pins_file" >&2
    return 1
  fi
  local rel f got
  for rel in "$ns_path" "$app_path" "$proj_path"; do
    case "$rel" in
      gitops/schemas/*) ;;
      *)
        printf 'FAIL schema path escapes gitops/schemas/: %s\n' "$rel" >&2
        return 1
        ;;
    esac
    f="${repo_root}/${rel}"
    if [[ ! -f "$f" ]]; then
      printf 'FAIL missing required schema %s\n' "$rel" >&2
      return 1
    fi
  done
  f="${repo_root}/${ns_path}"
  got="$(sha256_file "$f")"
  if [[ "$got" != "$ns_sha" ]]; then
    printf 'FAIL schema hash mismatch %s: got %s want %s\n' "$ns_path" "$got" "$ns_sha" >&2
    return 1
  fi
  f="${repo_root}/${app_path}"
  got="$(sha256_file "$f")"
  if [[ "$got" != "$app_sha" ]]; then
    printf 'FAIL schema hash mismatch %s: got %s want %s\n' "$app_path" "$got" "$app_sha" >&2
    return 1
  fi
  f="${repo_root}/${proj_path}"
  got="$(sha256_file "$f")"
  if [[ "$got" != "$proj_sha" ]]; then
    printf 'FAIL schema hash mismatch %s: got %s want %s\n' "$proj_path" "$got" "$proj_sha" >&2
    return 1
  fi
  return 0
}

assert_nonzero_schema_check() {
  local desc="$1"
  local pins_file="$2"
  local repo_root="$3"
  local out code
  set +e
  out="$(verify_committed_schemas "$pins_file" "$repo_root" 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
  if [[ "$code" -eq 0 ]]; then
    printf 'FAIL %s: wanted non-zero, got 0\n' "$desc" >&2
    exit 1
  fi
  printf 'ok negative %s (exit %s)\n' "$desc" "$code"
}

[[ -f "$pins" ]] || fail "missing ${pins}"

k8s_version="$(pin_get_from "$pins" kubernetes_schema_version)"
[[ -n "$k8s_version" ]] || fail "kubernetes_schema_version pin missing"

if ! verify_committed_schemas "$pins" "$root"; then
  fail "committed schema path or SHA-256 check failed"
fi
printf 'ok committed schema paths and SHA-256 (namespace, application, appproject)\n'

neg_root="$root/testdata/gitops-validate-negatives"
[[ -d "$neg_root/missing-pin-file" ]] || fail "missing negative fixture testdata/gitops-validate-negatives/missing-pin-file"
[[ -d "$neg_root/missing-application-schema" ]] || fail "missing negative fixture testdata/gitops-validate-negatives/missing-application-schema"
assert_nonzero_schema_check 'missing pin file' \
  "$neg_root/missing-pin-file/GITOPS_PINS.md" \
  "$neg_root/missing-pin-file"
assert_nonzero_schema_check 'missing individual required schema' \
  "$neg_root/missing-application-schema/GITOPS_PINS.md" \
  "$neg_root/missing-application-schema"

kustomize_version="$(pin_get_from "$pins" kustomize_version)"
kustomize_archive="$(pin_get_from "$pins" kustomize_archive)"
kustomize_archive_url="$(pin_get_from "$pins" kustomize_archive_url)"
kustomize_archive_sha256="$(pin_get_from "$pins" kustomize_archive_sha256)"
kustomize_binary_sha256="$(pin_get_from "$pins" kustomize_binary_sha256_linux_amd64)"
kubeconform_version="$(pin_get_from "$pins" kubeconform_version)"
kubeconform_archive="$(pin_get_from "$pins" kubeconform_archive)"
kubeconform_archive_url="$(pin_get_from "$pins" kubeconform_archive_url)"
kubeconform_archive_sha256="$(pin_get_from "$pins" kubeconform_archive_sha256)"
kubeconform_binary_sha256="$(pin_get_from "$pins" kubeconform_binary_sha256_linux_amd64)"

[[ -n "$kustomize_version" && -n "$kustomize_archive_sha256" ]] || fail "kustomize pins missing"
[[ -n "$kubeconform_version" && -n "$kubeconform_archive_sha256" ]] || fail "kubeconform pins missing"

install_pinned_binary() {
  local name="$1"
  local archive="$2"
  local url="$3"
  local archive_sha="$4"
  local binary_sha="$5"
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
    tar --no-same-owner -xzf "$archive" "$name"
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
  "$kustomize_archive_sha256" "$kustomize_binary_sha256"
install_pinned_binary kubeconform "$kubeconform_archive" "$kubeconform_archive_url" \
  "$kubeconform_archive_sha256" "$kubeconform_binary_sha256"

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
