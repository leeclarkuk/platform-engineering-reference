# ADR-0004: Helm-only golden path; no second workload manifest set

- Status: Accepted
- Date: 2026-09-03

## Context

Archive history shipped both `kubernetes/base` (Deployment, Service,
ServiceAccount, HPA, PDB, NetworkPolicy) and a Helm chart for the same
sample service. GitOps pointed at Helm only. If both were applied they
would compete for the same namespaced objects.

## Decision

The golden path packages a service as **one Helm chart** reconciled by
Argo CD. There is no parallel full Kustomize base for the same namespaced
workload. Environment differences are Helm values under GitOps.
Kustomize may build Argo CD Applications and platform add-on lists; it
must not duplicate the application Deployment/Service/ServiceAccount.

## Consequences

* Later `workloads/` or `templates/` contain Helm, not a second copy of
  the same objects.
* IRSA annotations are not the golden path (see ADR-0002: Pod Identity
  association in Terraform). Helm may expose an escape-hatch value, not a
  second manifest tree.

## Rejected options

* Dual Helm + `kubernetes/base` for the same service.
* Raw manifests as the default golden path (allowed later only as an
  explicit escape hatch, not the paved path).

## Review trigger

A PR that adds a Kustomize base Deployment/Service/ServiceAccount for a
service that already has a Helm chart.
