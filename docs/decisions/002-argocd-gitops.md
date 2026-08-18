# ADR-002: Argo CD for GitOps

- Status: Accepted
- Date: 2026-08-18

## Context

Workloads on EKS, AKS and GKE need a common promotion path. CI already builds
and scans images. Something has to reconcile cluster state continuously and
make drift visible.

## Options considered

1. **Argo CD.** Pull-based, widely operated, ApplicationSet for many
   clusters, decent RBAC and SSO story.
2. **Flux.** Equally serious, tighter Kubernetes-native APIs, smaller UI,
   strong OCI support.
3. **CI push (kubectl/helm from GitHub Actions).** Simple, maps to existing
   pipelines, credentials in the pipeline, no drift detection.
4. **Rancher / a vendor GitOps bundle.** Faster if you are buying a platform,
   more coupled if you are building one.

## Decision

Argo CD is the GitOps reconciler. CI never deploys to a cluster except for
break-glass documented in a runbook.

## Rationale

The operating model we want is: Git is desired state, the cluster converges,
humans look at sync status rather than pipeline logs. Argo CD is the tool
most platform engineers can already staff, and ApplicationSets match a
hub-of-clusters layout without a custom operator.

Flux is not worse. It is a peer. We picked Argo CD because the UI matters
when you are teaching application teams to own their applications, and
because the hiring market for Argo CD is slightly thicker. That is a people
decision, not a purity decision.

Push-from-CI is how a lot of estates still work. It hides drift, puts cluster
credentials in the pipeline, and teaches teams that "green tick" means
"running in production". It does not.

## Trade-offs

* Argo CD is another control plane to patch, SSO, backup and threat-model.
* App-of-apps and ApplicationSets can become a maze. We keep a shallow tree:
  bootstrap, platform add-ons, application root.
* Multi-tenancy inside one Argo CD is possible and easy to get wrong. Early
  on, platform project vs application project is enough.

## Consequences

* Image tags are written to Git by CI (or a promotion PR). Argo CD does not
  build images.
* Cluster bootstrap is itself GitOps after the first install.
* Helm is the packaging format for the golden path. Raw manifests are allowed
  as an escape hatch.

## When we would reconsider

* A Flux-first team with existing controllers and no appetite for Argo CD's
  UI.
* A decision to standardise on OCI-stored manifests only, where Flux's
  artefact flow is the clearer design.
* Managed GitOps from the cloud provider that actually meets SSO, audit and
  multi-cluster needs. We have not seen that bar cleared often.
