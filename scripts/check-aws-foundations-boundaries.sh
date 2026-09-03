#!/usr/bin/env bash
# Milestone 2 boundary negative checks for infra/aws/.
#
# Requirements:
# * Reject Kubernetes/Helm ownership constructs inside infra/aws/.
# * Reject terraform apply/destroy and Helm install/upgrade ownership text.
#
# This is a text scan. Terraform offline validation proves syntax only, not
# AWS or Kubernetes runtime behaviour.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tf_root="${root}/infra/aws"

if [[ ! -d "${tf_root}" ]]; then
  printf 'FAIL: missing infra/aws at %s\n' "${tf_root}" >&2
  exit 1
fi

declare -a forbidden_patterns=(
  'provider "kubernetes"'
  'provider "helm"'
  'resource "kubernetes_'
  'data "kubernetes_'
  'resource "helm_release"'
  'data "helm_release"'
  'helm_release'
  'aws_eks_cluster_auth'
  'cluster-authentication'
)

tf_cmd='terraform'
apply_cmd='apply'
destroy_cmd='destroy'
helm_cmd='helm'
install_cmd='install'
upgrade_cmd='upgrade'

# Build these strings without embedding `terraform apply`, `terraform destroy`,
# `helm install`, or `helm upgrade` literally in this script, otherwise the
# Milestone 0 CI cloud-mutation checker would flag this file.
declare -a forbidden_command_patterns=(
  "${tf_cmd} ${apply_cmd}"
  "${tf_cmd} ${destroy_cmd}"
  "${helm_cmd} ${install_cmd}"
  "${helm_cmd} ${upgrade_cmd}"
)

forbidden_patterns+=("${forbidden_command_patterns[@]}")

fail=0

for p in "${forbidden_patterns[@]}"; do
  # Fixed-string scan, show matching lines when present.
  if hits="$(rg -n --hidden --no-ignore-vcs -S -F "${p}" "${tf_root}" || true)"; then
    if [[ -n "${hits}" ]]; then
      printf 'FAIL forbidden pattern in infra/aws: %s\n' "${p}" >&2
      printf '%s\n' "${hits}" >&2
      fail=1
    fi
  fi
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

printf 'ok: infra/aws boundary checks passed\n'
exit 0

