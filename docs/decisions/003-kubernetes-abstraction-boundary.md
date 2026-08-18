# ADR-003: Kubernetes abstraction boundary

- Status: Accepted
- Date: 2026-08-18

## Context

The same example workload should run on EKS, AKS and GKE. The temptation is
to abstract the clouds completely, or to make every team learn three
providers. We need a boundary that is honest about what is portable.

## Options considered

1. **Kubernetes plus Helm/GitOps as the portability layer.** Cloud-specific
   foundations remain native. Overlays handle IRSA vs Workload Identity vs
   GKE WI.
2. **Cross-cloud Terraform modules** (`cluster`, `network`, `dns`) with
   provider switches. Looks tidy. Leaks in every non-happy path.
3. **A lowest-common-denominator PaaS** (internal Heroku). Highest cognitive
   load reduction, highest platform-team cost, worst escape hatch.
4. **No portability.** Each cloud is a separate platform. Honest, expensive
   for teams that genuinely have to span providers.

## Decision

Kubernetes is the abstraction boundary for stateless and twelve-factor style
services. Landing zones, identity stores, hub networking and data platforms
stay provider-native.

A service mesh is not part of the boundary. See the Kubernetes architecture
note for when it would be justified.

## Rationale

Containers, probes, resource limits, network policy and an OpenTelemetry SDK
travel. Transit Gateway attachments do not. Pretending otherwise produces a
module that is always "80% done" and 100% owned by the platform team when it
breaks.

A full internal PaaS can be the right product for a large organisation with
a stable runtime shape. It is the wrong first product. You cannot hide
failure modes you have not yet operated.

## Trade-offs

* Stateful systems (Oracle, Windows, vendor appliances, some data planes)
  will not live on this path. They need a different golden path or none.
* Kubernetes itself is a portability tax. Teams that only run on AWS Lambda
  should not be forced through EKS to satisfy a diagram.
* Provider overlays still exist. Workload identity annotations differ. That
  difference is documented, not hidden behind a fake common CRD.

## Consequences

* `kubernetes/base` is the contract. `eks` / `aks` / `gke` are overlays.
* Terraform modules are not shared across clouds except for naming and tags.
* "Run it on Kubernetes" is not the default answer for batch, data or COTS.

## When we would reconsider

* A single-cloud strategy where EKS (or AKS, or GKE) plus native PaaS is
  simpler than a portable contract.
* A true internal PaaS with enough users to fund the control plane.
* Workloads that are compute-portable but data-gravity-bound: then
  portability of the API tier may still hold while the database does not.
