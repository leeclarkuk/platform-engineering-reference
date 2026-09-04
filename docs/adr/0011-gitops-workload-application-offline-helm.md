# ADR-0011: GitOps workload Application sample and offline Helm gate

- Status: Accepted
- Date: 2026-09-04

## Context

Milestone 3 placed Argo CD bootstrap desired state under `gitops/` and
proved an offline render gate. `gitops/apps` was an empty Kustomize list.
AppProject `platform` existed but had no Application. The Helm chart
under `templates/` was a Milestone 1 skeleton on disk, not a GitOps
source.

Lee approved Milestone 4 implementation: harden both AppProjects first,
then add exactly one workload Application named `sample` that points at
the existing chart root. Proof stays local. There is no live Argo CD
sync, no workload run, no operational Pod Identity, and no journey.

The Helm chart was rendered with the pinned client before this decision
was applied. The render was Deployment, Service, and ServiceAccount
`apps/sample`, with the Deployment using ServiceAccount `sample`. The
chart was not edited.

## Decision

Accepted because Lee approved this specification, including
ARCHITECTURE_CHOICE.

* AppProject allow surfaces fail closed. Either AppProject that sets
  `clusterResourceWhitelist` (any contents) fails. Any wildcard in
  `sourceRepos`, destinations, namespaces, or resource permissions
  fails. Live manifests contain neither `clusterResourceWhitelist` nor
  wildcard permissions.
* AppProject `bootstrap` stays privileged and namespaced
  `argoproj.io`/`Application` only. It destinations `argocd` only. It
  never hosts Application `sample`. It has no `clusterResourceWhitelist`.
* AppProject `platform` destinations namespace `apps` only, with
  `sourceRepos` exactly this repository. `namespaceResourceWhitelist` is
  exactly the three chart kinds: `apps`/`Deployment`, core `Service`,
  core `ServiceAccount` (the Argo CD group/kind form of Deployment
  `apps/v1`, Service `v1`, ServiceAccount `v1`). It cannot destination
  `argocd`. It has no cluster-scoped allow list.
* Application `gitops-root` is unchanged: project `bootstrap`, path
  `gitops/apps`, destination `argocd`, no `spec.syncPolicy`.
* Application `sample` has `metadata.name` `sample`,
  `metadata.namespace` `argocd`, `spec.project` `platform`, `repoURL`
  this repository, `targetRevision` `main`, `path` `templates` (exact
  chart root), destination in-cluster namespace `apps`. It omits
  `spec.syncPolicy` (no automated, prune, or selfHeal) and omits
  `spec.source.helm` valueFiles, values, and parameters.
* `gitops/apps/kustomization.yaml` resources is exactly
  `[application-sample.yaml]`. The GitOps root Kustomize list is
  unchanged on bootstrap objects plus `apps`.
* `make gitops-validate` keeps every Milestone 0 to Milestone 3 gate
  and adds: pinned Helm `lint` of `templates/`; deterministic
  `helm template sample templates` with no `--set` and no chart
  repository; fail-closed kubeconform of that render using committed
  Deployment, Service, and ServiceAccount schemas under
  `gitops/schemas/kubernetes`; field-level checks of both Applications,
  both AppProjects, the Helm render, the valid WorkloadContract fixture,
  and Milestone 2 identity strings `apps`/`sample`.
* Twenty named behaviours each have a committed executable fixture
  under `testdata/gitops-m4-negatives/`. The gate fails if any of those
  fixtures exits 0. This is not a test-count target.
* Pins for Helm version, archive SHA-256, binary SHA-256, and the new
  schema paths are recorded in `gitops/GITOPS_PINS.md` from published
  or computed evidence. Existing Go, checkout, Terraform, provider,
  kustomize, kubeconform, Argo schema, and Action pins are unchanged.
  No new GitHub Action. `persist-credentials: false` stays. The
  workflow does not gain `actions: write`. `make help` stays plain
  quoted text.

## Consequences

* Milestone 4 proves syntactic and offline validation only. It does not
  prove a live Argo CD sync, a running workload, operational Pod
  Identity, or a journey.
* Terraform `kubernetes_*` / `helm_release` remain forbidden. GitOps
  must not grow IAM or Terraform objects. `gitops/apps` remains
  orchestration only: no copied Deployment, Service, or ServiceAccount.
* Identity `apps`/`sample` is the same string as the WorkloadContract
  fixture and the Milestone 2 Terraform input defaults. That is a
  string check, not a live association.

## Rejected options

* `clusterResourceWhitelist` on either AppProject.
* Wildcard `sourceRepos`, destinations, namespaces, or resource
  permissions.
* Workload Application on project `bootstrap`, or `gitops-root` on
  project `platform`.
* Auto-sync, prune, or selfHeal on either Application.
* Helm `valueFiles` / values / parameters that duplicate chart
  defaults, `--set` in the gate, or a chart repository.
* A second platform workload Application.
* Raw Deployment/Service/ServiceAccount under `gitops/apps`.
* Editing `templates/**` without a proved Helm render defect.
* Remote kubeconform schema URLs, `--ignore-missing-schemas`,
  `kubectl apply`, Helm install/upgrade, Argo CD API mutation,
  Terraform apply/destroy, or AWS API as the proof.

## Review trigger

A PR that adds `clusterResourceWhitelist`, a wildcard allow, a second
platform Application, auto-sync, Helm `--set` in the gate, a live
sync claim, or a copied workload manifest under `gitops/apps/`.
