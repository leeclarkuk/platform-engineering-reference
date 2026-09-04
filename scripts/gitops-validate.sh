#!/usr/bin/env bash
# Offline GitOps render, Helm lint/template, local-schema kubeconform, and
# semantic boundary checks. Tool installation may use the network.
# Validation does not configure remote schema URLs and does not apply,
# kubectl, helm install, or mutate Argo CD.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Validation must not use cloud credentials or a kubeconfig.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
unset AWS_DEFAULT_REGION AWS_REGION AWS_SHARED_CREDENTIALS_FILE
unset KUBECONFIG
export KUBECONFIG=/dev/null

pins="$root/gitops/GITOPS_PINS.md"
k8s_schema_dir="$root/gitops/schemas/kubernetes"
argo_schema_dir="$root/gitops/schemas/argocd"
cache_dir="$root/.cache/gitops-tools"
m4_neg="$root/testdata/gitops-m4-negatives"

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

schema_keys=(
  kubernetes_namespace_schema_path:kubernetes_namespace_schema_sha256
  kubernetes_deployment_schema_path:kubernetes_deployment_schema_sha256
  kubernetes_service_schema_path:kubernetes_service_schema_sha256
  kubernetes_serviceaccount_schema_path:kubernetes_serviceaccount_schema_sha256
  argocd_application_schema_path:argocd_application_schema_sha256
  argocd_appproject_schema_path:argocd_appproject_schema_sha256
)

helm_pin_keys=(
  helm_version
  helm_archive
  helm_archive_url
  helm_archive_sha256
  helm_binary_sha256_linux_amd64
)

# Verify committed schema paths, SHA-256 values, and Helm pin keys.
# repo_root is the tree the pin paths are relative to. Prints FAIL to stderr
# and returns non-zero; does not exit the process (so negatives can use it).
verify_committed_schemas() {
  local pins_file="$1"
  local repo_root="$2"
  if [[ ! -f "$pins_file" ]]; then
    printf 'FAIL missing pin file %s\n' "$pins_file" >&2
    return 1
  fi
  local key
  for key in "${helm_pin_keys[@]}"; do
    if [[ -z "$(pin_get_from "$pins_file" "$key")" ]]; then
      printf 'FAIL pin file missing Helm pin key %s: %s\n' "$key" "$pins_file" >&2
      return 1
    fi
  done
  local pair path_key sha_key rel sha f got
  for pair in "${schema_keys[@]}"; do
    path_key="${pair%%:*}"
    sha_key="${pair##*:}"
    rel="$(pin_get_from "$pins_file" "$path_key")"
    sha="$(pin_get_from "$pins_file" "$sha_key")"
    if [[ -z "$rel" ]]; then
      printf 'FAIL pin file missing schema path key %s: %s\n' "$path_key" "$pins_file" >&2
      return 1
    fi
    if [[ -z "$sha" ]]; then
      printf 'FAIL pin file missing schema sha256 key %s: %s\n' "$sha_key" "$pins_file" >&2
      return 1
    fi
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
    got="$(sha256_file "$f")"
    if [[ "$got" != "$sha" ]]; then
      printf 'FAIL schema hash mismatch %s: got %s want %s\n' "$rel" "$got" "$sha" >&2
      return 1
    fi
  done
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
  printf 'ok named negative %s (exit %s)\n' "$desc" "$code"
}

[[ -f "$pins" ]] || fail "missing ${pins}"

k8s_version="$(pin_get_from "$pins" kubernetes_schema_version)"
[[ -n "$k8s_version" ]] || fail "kubernetes_schema_version pin missing"

if ! verify_committed_schemas "$pins" "$root"; then
  fail "committed schema path or SHA-256 check failed"
fi
printf 'ok committed schema paths and SHA-256 (namespace, deployment, service, serviceaccount, application, appproject) plus Helm pins\n'

neg_root="$root/testdata/gitops-validate-negatives"
[[ -d "$neg_root/missing-pin-file" ]] || fail "missing negative fixture testdata/gitops-validate-negatives/missing-pin-file"
[[ -d "$neg_root/missing-application-schema" ]] || fail "missing negative fixture testdata/gitops-validate-negatives/missing-application-schema"
assert_nonzero_schema_check 'missing pin file' \
  "$neg_root/missing-pin-file/GITOPS_PINS.md" \
  "$neg_root/missing-pin-file"
assert_nonzero_schema_check 'missing individual required schema' \
  "$neg_root/missing-application-schema/GITOPS_PINS.md" \
  "$neg_root/missing-application-schema"

[[ -d "$m4_neg/missing-helm-pin-or-schema" ]] || fail "missing M4 fixture missing-helm-pin-or-schema"
[[ -d "$m4_neg/stale-schema-hash" ]] || fail "missing M4 fixture stale-schema-hash"
assert_nonzero_schema_check 'missing Helm pin, local schema, or recorded hash' \
  "$m4_neg/missing-helm-pin-or-schema/GITOPS_PINS.md" \
  "$m4_neg/missing-helm-pin-or-schema"
assert_nonzero_schema_check 'modified vendored schema with stale hash' \
  "$m4_neg/stale-schema-hash/GITOPS_PINS.md" \
  "$m4_neg/stale-schema-hash"

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
helm_version="$(pin_get_from "$pins" helm_version)"
helm_archive="$(pin_get_from "$pins" helm_archive)"
helm_archive_url="$(pin_get_from "$pins" helm_archive_url)"
helm_archive_sha256="$(pin_get_from "$pins" helm_archive_sha256)"
helm_binary_sha256="$(pin_get_from "$pins" helm_binary_sha256_linux_amd64)"

[[ -n "$kustomize_version" && -n "$kustomize_archive_sha256" ]] || fail "kustomize pins missing"
[[ -n "$kubeconform_version" && -n "$kubeconform_archive_sha256" ]] || fail "kubeconform pins missing"
[[ -n "$helm_version" && -n "$helm_archive_sha256" && -n "$helm_binary_sha256" ]] || fail "Helm pins missing"

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

install_pinned_helm() {
  local archive="$1"
  local url="$2"
  local archive_sha="$3"
  local binary_sha="$4"
  mkdir -p "$cache_dir"
  local dest="$cache_dir/helm"
  if [[ -x "$dest" ]]; then
    local got_bin
    got_bin="$(sha256_file "$dest")"
    if [[ "$got_bin" == "$binary_sha" ]]; then
      printf 'ok cached helm sha256 %s\n' "$got_bin"
      return 0
    fi
    printf 'cached helm hash mismatch; reinstalling\n'
    rm -f "$dest"
  fi
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    curl -fsSL -o "$archive" "$url"
    got="$(sha256_file "$archive")"
    if [[ "$got" != "$archive_sha" ]]; then
      printf 'FAIL helm archive sha256 mismatch: got %s want %s\n' "$got" "$archive_sha" >&2
      exit 1
    fi
    tar --no-same-owner -xzf "$archive" linux-amd64/helm
    got_bin="$(sha256_file linux-amd64/helm)"
    if [[ "$got_bin" != "$binary_sha" ]]; then
      printf 'FAIL helm binary sha256 mismatch: got %s want %s\n' "$got_bin" "$binary_sha" >&2
      exit 1
    fi
    install -m 0755 linux-amd64/helm "$dest"
  )
  rm -rf "$tmp"
  printf 'ok installed helm from pinned archive\n'
}

install_pinned_binary kustomize "$kustomize_archive" "$kustomize_archive_url" \
  "$kustomize_archive_sha256" "$kustomize_binary_sha256"
install_pinned_binary kubeconform "$kubeconform_archive" "$kubeconform_archive_url" \
  "$kubeconform_archive_sha256" "$kubeconform_binary_sha256"
install_pinned_helm "$helm_archive" "$helm_archive_url" \
  "$helm_archive_sha256" "$helm_binary_sha256"

export PATH="$cache_dir:$PATH"

got_kustomize="$(kustomize version)"
[[ "$got_kustomize" == "v${kustomize_version}" ]] || fail "kustomize version ${got_kustomize} != v${kustomize_version}"
got_kubeconform="$(kubeconform -v)"
[[ "$got_kubeconform" == "v${kubeconform_version}" ]] || fail "kubeconform version ${got_kubeconform} != v${kubeconform_version}"
got_helm="$(helm version --template '{{.Version}}')"
[[ "$got_helm" == "v${helm_version}" ]] || fail "helm version ${got_helm} != v${helm_version}"
printf 'ok kustomize %s\n' "$got_kustomize"
printf 'ok kubeconform %s\n' "$got_kubeconform"
printf 'ok helm %s\n' "$got_helm"

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
[[ -s "$render_dir/apps.yaml" ]] || fail "kustomize build gitops/apps produced no YAML (M4 sample Application required)"
printf 'ok kustomize build gitops (%s bytes)\n' "$(wc -c < "$render_dir/gitops.yaml" | tr -d ' ')"
printf 'ok kustomize build gitops/apps (%s bytes)\n' "$(wc -c < "$render_dir/apps.yaml" | tr -d ' ')"

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
run_kubeconform "$render_dir/apps.yaml"

helm_lint_args=(lint "$root/templates")
helm_template_args=(template sample "$root/templates" --kube-version "$k8s_version")
printf '%s\n' "${helm_template_args[@]}" | grep -Fq -- '--set' && fail "helm template must not pass --set"
printf '%s\n' "${helm_lint_args[@]}" "${helm_template_args[@]}" | grep -Fq -- '--repo' && fail "helm must not use a chart repository"
helm "${helm_lint_args[@]}"
printf 'ok helm lint templates/\n'
helm "${helm_template_args[@]}" > "$render_dir/helm.yaml"
[[ -s "$render_dir/helm.yaml" ]] || fail "helm template produced no YAML"
printf 'ok helm template templates (%s bytes; no --set; no chart repo)\n' "$(wc -c < "$render_dir/helm.yaml" | tr -d ' ')"

run_kubeconform "$render_dir/helm.yaml"
printf 'ok kubeconform helm render (Deployment, Service, ServiceAccount; local schemas only)\n'

"$root/scripts/check-gitops-semantics.sh" "$render_dir/helm.yaml"

# Named negative 19: execute the exact M4 Terraform fixture. Do not treat
# the M2 fixture suite as a substitute. Named negative 20: mutation path.
"$root/scripts/check-aws-foundations-boundaries.sh"
printf 'ok existing M2 Terraform K8s/Helm boundary check\n'

assert_nonzero 'k8s-helm-under-terraform' \
  "$root/scripts/check-aws-foundations-boundaries.sh" "$m4_neg/k8s-helm-under-terraform"

assert_nonzero 'live-mutation-in-validation' \
  "$root/scripts/check-no-cloud-mutation.sh" "$m4_neg/live-mutation-in-validation"

printf 'ok gitops-validate (local schemas only; no cluster; no apply)\n'
