# ADR-0005: No Backstage, Crossplane, service mesh, or AI control plane

- Status: Accepted
- Date: 2026-09-03

## Context

Portals, universal cloud CRDs, meshes and model-driven remediation expand
on-call surface before a golden path exists. Archive ADR-009 deferred a
developer portal until several teams used the path. This tree starts empty.

## Decision

Out of scope until an explicit later ADR supersedes this one:

* Backstage or any developer portal UI
* Crossplane (or Kubernetes as the first cloud control plane)
* A service mesh as a default
* AI/MCP/autonomous remediation, model-written Terraform, or merge/deploy
  by an agent without a human

The first developer interface is documentation plus, in a later milestone,
a small CLI. Git remains the catalogue.

## Consequences

* Milestone 0 does not add those products.
* Hiring and operations stay Git, Make, later Terraform, EKS and Argo CD.

## Rejected options

* Portal-first platform.
* Crossplane for landing zones.
* Mesh by default.
* AI as an owner of infrastructure changes.

## Review trigger

A proposal to add Backstage, Crossplane, a mesh, or an AI control plane
before a Helm golden path has been locally proved on this lineage.
