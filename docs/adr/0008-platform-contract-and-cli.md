# ADR-0008: Platform contract and CLI

- Status: Accepted
- Date: 2026-09-03

## Context

Milestone 1 needs a versioned workload contract and a local CLI that does
not require cloud credentials. Later drafts proposed a different kind
name, a different schema path, a Go-module-only milestone without Helm,
and a scalar ServiceAccount field. Lee's approved specification remains
binding.

## Decision

Accepted because Lee approved the Milestone 1 contract and CLI
boundary.

* Kind is `WorkloadContract`. `apiVersion` is
  `platform.engineering.reference/v1alpha1`. The schema lives under
  `api/v1alpha1/`. There is no second contract alias.
* The only legal `spec.goldenPath` is `helm` (ADR-0004). Milestone 1
  ships one Helm chart skeleton under `templates/` as files on disk,
  not a deploy.
* ServiceAccount identity is the object
  `spec.serviceAccount.namespace` plus `spec.serviceAccount.name`
  (ADR-0002 contract strings), not a live Kubernetes object.
* Kubernetes identifiers in the contract are RFC 1123 DNS labels:
  `metadata.name`, `spec.serviceAccount.namespace`, and
  `spec.serviceAccount.name`. JSON Schema pattern
  `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$` with `maxLength` 63.
  `platform create` rejects invalid names such as `Demo`.
* The CLI is stdlib only (`flag`, `os`, no Cobra): `platform doctor`,
  `platform validate <file>`, `platform create --name --owner
  --namespace [--out-dir DIR]`.
* `platform doctor` requires `git`, `make`, and `go`. It must succeed
  with `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_SESSION_TOKEN`, and `AWS_PROFILE` unset. It does not read those
  variables and does not call AWS.
* `platform create` writes a valid WorkloadContract YAML and one Helm
  chart skeleton. It fails if the output directory already exists. It
  writes no Terraform, GitOps apply, IAM, kubeconfig, or secrets.
* AWS identifiers, IAM, VPC, cluster, Terraform, and GitOps apply
  fields are forbidden in the schema (`additionalProperties: false`).

## Consequences

* `make platform-test` runs `go test ./...` and CLI positive/negative
  checks. CI runs that target in addition to Milestone 0 gates.
* Later AWS and GitOps milestones consume the contract strings. They do
  not change the kind and they do not drop the Helm skeleton.
* Dormant AWS and GitOps builders still refuse writes outside later
  `infra/aws/` and `gitops/`.

## Rejected options

* Kind `DeployableService`.
* Schema path `api/contract/v1/`.
* A no-Helm Milestone 1 / Go-module-only tree.
* Scalar `spec.serviceAccountName` (or any second contract alias).
* Product path `product/m1-contract-cli`.
* `goldenPath: kustomize` as a legal value.
* Requiring AWS credentials for `platform doctor`.
* Overwriting an existing create destination directory.

## Review trigger

A proposal to rename the kind, to move the schema to `api/contract/v1/`,
to drop the Helm skeleton, to replace the ServiceAccount object with a
scalar, to add AWS fields to the contract, to add a second Kustomize
workload set, or to make `platform doctor` call AWS.
