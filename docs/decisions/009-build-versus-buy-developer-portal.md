# ADR-009: Build versus buy developer portal

- Status: Accepted
- Date: 2026-08-18

## Context

Platforms are asked for a portal before they have a path. Catalogues, score
cards and plugin ecosystems are attractive. They do not create a golden path
on their own.

## Options considered

1. **Buy / adopt Backstage (or a managed equivalent) now.**
2. **Build a thin internal portal.**
3. **Defer the portal.** CLI + Git + service-catalogue YAML + docs until
   the golden path is used by real teams.
4. **Use the cloud vendor's portal** (Service Catalog, Azure Deployment
   Environments). Good for IaaS vending, weak as a software catalogue.

## Decision

Defer the portal. Invest in the CLI, templates, CI, GitOps and a YAML
service catalogue. Revisit when at least several teams use the golden path
and discovery, not scaffolding, is the bottleneck.

## Rationale

Backstage is a reasonable product and an unreasonable first dependency. It
needs identity, a running instance, plugin maintenance and a content team.
Without those, you have a website that says "Hello World" next to a platform
that still cannot produce a service.

Cloud vendor catalogues help with account vending. They do not replace
ownership metadata, runbooks and SLO documents in Git.

Building a custom portal is how platform teams avoid talking to users. We
are not doing that.

## Trade-offs

* Discovery will be worse than a good Backstage install. Engineers will
  grep the catalogue YAML. That is acceptable at small scale.
* Executives like portals. The operating model document is the answer to
  that request, not a hastily deployed catalogue.
* When we do adopt a portal, templates must already be clean, or we will
  encode a mess in software templates.

## Consequences

* `developer-platform/service-catalogue` is Git-shaped, not a product.
* No Backstage deployment lives in this repository yet.
* Scorecards, if any, start as CI checks (policy, Dockerfile, probes),
  not as a plugin.

## When we would reconsider

* Several teams on the path and a clear discovery problem.
* A managed Backstage (or equivalent) with an owner who is not the same
  two people who run Kubernetes.
* A compliance need for a single ownership register that YAML in Git cannot
  satisfy. Even then, Git remains the source of truth and the portal reads
  it.
