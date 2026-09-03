# ADR-0008: Platform contract and CLI

- Status: Accepted
- Date: 2026-09-03

## Context

Milestone 1 needs a versioned workload contract and a local CLI that does
not require cloud credentials. A later architect draft proposed renaming
the kind to DeployableService. Lee's approved specification remains
binding: the kind is WorkloadContract, and the Helm chart skeleton stays
under `templates/` as files on disk, not a deploy.

## Decision

Accepted because Lee approved the Milestone 1 specification. Later
architect additions that do not change the kind are folded in here.

* Kind is `WorkloadContract`. `apiVersion` is
  `platform.engineering.reference/v1alpha1`. The schema lives under
  `api/v1alpha1/`.
* The only legal `spec.goldenPath` is `helm` (ADR-0004). There is no
  parallel Kustomize workload set.
* `spec.serviceAccount.namespace` and `spec.serviceAccount.name` are
  ADR-0002 contract strings, not a live Kubernetes ServiceAccount.
* `metadata.name` is a DNS-1123 label: lowercase letters, digits, and
  hyphens; it must start and end with an alphanumeric character.
* The CLI is stdlib only (`flag`, `os`, no Cobra): `platform doctor`,
  `platform validate <file>`, `platform create --name --owner
  --namespace [--out-dir DIR]` (DIR may also be positional).
* `platform doctor` requires `git`, `make`, and `go`. It must succeed
  with `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_SESSION_TOKEN`, and `AWS_PROFILE` unset. It does not call AWS.
* `platform create` writes a valid WorkloadContract YAML and one Helm
  chart skeleton. It rejects invalid names such as `Demo`. It fails if
  the output directory already exists. It writes no Terraform, GitOps
  apply, IAM, kubeconfig, or secrets.
* AWS identifiers, IAM, VPC, cluster, Terraform, and GitOps apply
  fields are forbidden in the schema (`additionalProperties: false`).

## Consequences

* `make platform-test` runs `go test ./...` and CLI positive/negative
  checks, including missing-file and wrong apiVersion/kind validate
  cases. CI runs that target in addition to Milestone 0 gates.
* Later AWS and GitOps milestones consume the contract strings. They do
  not change the kind and they do not drop the Helm skeleton.
* Dormant AWS and GitOps builders still refuse writes outside later
  `infra/aws/` and `gitops/`.

## Rejected options

* Kind `DeployableService`.
* Dropping the Helm skeleton under `templates/`.
* `goldenPath: kustomize` as a legal value.
* Requiring AWS credentials for `platform doctor`.
* Overwriting an existing create destination directory.

## Review trigger

A proposal to rename the kind, to drop the Helm skeleton, to add AWS
fields to the contract, to add a second Kustomize workload set, or to
make `platform doctor` call AWS.
