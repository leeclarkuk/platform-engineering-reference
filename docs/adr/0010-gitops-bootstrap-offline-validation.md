# ADR-0010: GitOps bootstrap (Milestone 3) projects, root application, and offline validation

- Status: Accepted
- Date: 2026-09-03

## Context

Milestone 3 adds Argo CD desired state for cluster bootstrap only. It is
a local render, lint, and semantic gate. It is not a live cluster, not a
synced application, and not Milestone 4 (no golden-path workload
Application). Terraform continues to own cloud-API objects (ADR-0002).
Kustomize may list Argo CD Applications and platform add-ons; it must
not duplicate the Helm golden-path workload (ADR-0004).

Lee approved the corrected specification, including: "only Application
gitops-root" means it is the only Application assigned to the privileged
bootstrap project, and that the gate must verify that application's
exact name, project, repository, revision, path, and destination.
Vendored schemas must be JSON schemas usable directly by kubeconform.
Tool installation may use the network. Validation must not.

## Decision

Accepted because Lee approved this specification.

* Desired state lives under `gitops/`. Bootstrap manifests are
  namespaces `argocd` and `apps`, AppProjects `bootstrap` and
  `platform`, and Application `gitops-root`. `gitops/apps` is a
  Kustomize list with `resources: []`. No Milestone 4 Application.
* AppProject `bootstrap` is privileged. `sourceRepos` is exactly
  `https://github.com/leeclarkuk/platform-engineering-reference`.
  Destinations are in-cluster server `https://kubernetes.default.svc`
  and namespace `argocd` only. It must not destination `apps`. It is
  used only by Application `gitops-root`.
* AppProject `platform` is unprivileged. Same `sourceRepos`. Destinations
  are the same server and namespace `apps` only. It must not destination
  `argocd`. No Milestone 3 Application uses it.
* Application `gitops-root` has `metadata.name` `gitops-root`,
  `spec.project` `bootstrap`, `repoURL` this repository,
  `targetRevision` `main`, `path` `gitops/apps`, destination in-cluster
  namespace `argocd`. `spec.syncPolicy` is omitted: no automated sync,
  prune, or selfHeal.
* Wildcards (`*`) in `sourceRepos`, destination namespaces, or
  destinations fail the semantic gate.
* `make gitops-validate` fails closed if `gitops/schemas/kubernetes` or
  `gitops/schemas/argocd` is missing or empty; runs `kustomize build`
  for `gitops` and `gitops/apps`; runs kubeconform on those renders with
  only `-schema-location` under `gitops/schemas/` (no remote schema
  URLs, no `--ignore-missing-schemas` for `argoproj.io` or Namespace);
  and runs `scripts/check-gitops-semantics.sh` against the live tree and
  committed fixtures under `testdata/gitops-boundaries/`.
* Pins for kustomize, kubeconform, GitHub Action SHAs, Kubernetes schema
  version, and Argo CD schema version are recorded in
  `gitops/GITOPS_PINS.md` from published or computed SHA-256 evidence.
  CI Go stays `1.22.12`. Terraform pins do not change.
  `persist-credentials: false` stays. GOV-003 is not expanded. The
  workflow does not gain `actions: write`.

## Consequences

* Milestone 3 proves syntactic and offline validation only. It does not
  prove a journey, a synced app, a live cluster, or operational Pod
  Identity.
* Terraform `kubernetes_*` / `helm_release` remain forbidden. GitOps
  must not grow IAM or Terraform objects.
* Later Milestone 4 may add a Helm Application under `gitops/apps/`
  assigned to project `platform`. It must not reuse project `bootstrap`.

## Rejected options

* Auto-sync, prune, or selfHeal on `gitops-root`.
* Wildcard `sourceRepos` or destination namespaces.
* Platform project managing `argocd` or bootstrap objects.
* Bootstrap project destination `apps`.
* Application source path `templates/`.
* Remote kubeconform schema URLs, or `--ignore-missing-schemas` for
  Namespace or `argoproj.io`.
* A Milestone 4 workload Application in this pull request.
* `kubectl apply`, Helm install/upgrade, Argo CD API mutation, Terraform
  apply/destroy, or AWS API as the proof.

## Review trigger

A PR that adds a second Application to project `bootstrap`, enables
auto-sync on `gitops-root`, points kubeconform at a remote schema,
places Terraform or IAM under `gitops/`, or claims live GitOps
reconciliation from this milestone.
