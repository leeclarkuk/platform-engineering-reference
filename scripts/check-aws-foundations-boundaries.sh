#!/usr/bin/env bash
# Milestone 2 boundary checks for a Terraform aws-root directory.
#
# Positive (repository infra/aws/):
# * Exactly three roots: bootstrap, network, workload.
# * No Kubernetes/Helm ownership constructs.
# * No apply/destroy or Helm install/upgrade text (whitespace-tolerant).
#
# Negative fixtures live under testdata/aws-foundations-boundaries/ and must
# fail this checker. They are not live Terraform roots.
#
# Lexical scan only. Not AWS or Kubernetes runtime proof.
# terraform init is not air-gapped; this script does not invoke Terraform.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
permitted_roots=$'bootstrap\nnetwork\nworkload'

tf_cmd='terraform'
apply_cmd='apply'
destroy_cmd='destroy'
helm_cmd='helm'
install_cmd='install'
upgrade_cmd='upgrade'

scan_aws_root() {
  local aws_root="$1"
  local fail=0
  local tf_file rel top roots_file got

  if [[ ! -d "${aws_root}" ]]; then
    printf 'FAIL: missing aws-root at %s\n' "${aws_root}" >&2
    return 1
  fi

  roots_file="$(mktemp)"
  while IFS= read -r tf_file; do
    [[ -n "${tf_file}" ]] || continue
    rel="${tf_file#"${aws_root}"/}"
    if [[ "${rel}" != */* ]]; then
      printf 'FAIL extra Terraform file at aws-root (not a permitted nested root): %s\n' "${rel}" >&2
      fail=1
      continue
    fi
    top="${rel%%/*}"
    printf '%s\n' "${top}"
  done < <(find "${aws_root}" -type f -name '*.tf' ! -path '*/.terraform/*' | sort) \
    > "${roots_file}.raw"
  sort -u "${roots_file}.raw" > "${roots_file}"
  rm -f "${roots_file}.raw"

  got="$(cat "${roots_file}")"
  if [[ "${got}" != "${permitted_roots}" ]]; then
    printf 'FAIL Terraform roots must be exactly bootstrap, network, workload in %s\n' "${aws_root}" >&2
    printf 'got:\n%s\n' "${got:-<none>}" >&2
    fail=1
  fi
  rm -f "${roots_file}"

  # Kubernetes / Helm ownership (quote-tolerant spacing).
  local -a ownership_regexes=(
    'provider[[:space:]]+"kubernetes"'
    'provider[[:space:]]+"helm"'
    'resource[[:space:]]+"kubernetes_'
    'data[[:space:]]+"kubernetes_'
    'resource[[:space:]]+"helm_release"'
    'data[[:space:]]+"helm_release"'
    'helm_release'
    'aws_eks_cluster_auth'
    'cluster-authentication'
  )

  # Built without writing the literal command text in this file.
  local -a command_regexes=(
    "${tf_cmd}[[:space:]]+${apply_cmd}"
    "${tf_cmd}[[:space:]]+${destroy_cmd}"
    "${helm_cmd}[[:space:]]+${install_cmd}"
    "${helm_cmd}[[:space:]]+${upgrade_cmd}"
  )

  local pattern hits
  for pattern in "${ownership_regexes[@]}" "${command_regexes[@]}"; do
    hits="$(grep -R -n -E -e "${pattern}" --exclude-dir='.terraform' "${aws_root}" || true)"
    if [[ -n "${hits}" ]]; then
      printf 'FAIL forbidden pattern in %s: %s\n' "${aws_root}" "${pattern}" >&2
      printf '%s\n' "${hits}" >&2
      fail=1
    fi
  done

  if [[ "${fail}" -ne 0 ]]; then
    return 1
  fi
  printf 'ok: aws-root boundary checks passed: %s\n' "${aws_root}"
  return 0
}

assert_nonzero_scan() {
  local desc="$1"
  local path="$2"
  local out code
  set +e
  out="$(scan_aws_root "${path}" 2>&1)"
  code=$?
  set -e
  printf '%s\n' "${out}"
  if [[ "${code}" -eq 0 ]]; then
    printf 'FAIL %s: wanted non-zero, got 0\n' "${desc}" >&2
    exit 1
  fi
  printf 'ok %s (exit %s)\n' "${desc}" "${code}"
}

real_root="${root}/infra/aws"

# Fixture-only mode: scan the given aws-root path(s) and return that result.
# Used to execute testdata/gitops-m4-negatives/k8s-helm-under-terraform.
# Default (no args) still scans live infra/aws plus M2 fixtures.
if [[ $# -gt 0 ]]; then
  rc=0
  for p in "$@"; do
    if ! scan_aws_root "${p}"; then
      rc=1
    fi
  done
  exit "${rc}"
fi

scan_aws_root "${real_root}"

fixtures="${root}/testdata/aws-foundations-boundaries"
assert_nonzero_scan 'fourth Terraform root' "${fixtures}/fourth-root"
assert_nonzero_scan 'Kubernetes ownership' "${fixtures}/kubernetes"
assert_nonzero_scan 'Helm ownership' "${fixtures}/helm"
assert_nonzero_scan 'whitespace-tolerant apply' "${fixtures}/apply"
assert_nonzero_scan 'whitespace-tolerant destroy' "${fixtures}/destroy"

printf 'ok: infra/aws boundary checks passed (positives and negative fixtures)\n'
exit 0
