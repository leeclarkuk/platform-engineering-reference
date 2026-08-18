# Architecture decision records

Decisions that bind the platform live here. Pull request descriptions are not
a substitute.

## Format

Each ADR uses:

* Status
* Context
* Options considered
* Decision
* Rationale
* Trade-offs
* Consequences
* When we would reconsider

Status is `proposed`, `accepted`, `superseded` or `rejected`.

## Index

| ID | Title | Status |
| --- | --- | --- |
| [001](001-terraform-primary-iac.md) | Terraform as the primary IaC tool | Accepted |
| [002](002-argocd-gitops.md) | Argo CD for GitOps | Accepted |
| [003](003-kubernetes-abstraction-boundary.md) | Kubernetes abstraction boundary | Accepted |
| [004](004-multi-cloud-strategy.md) | Multi-cloud strategy | Accepted |
| [005](005-centralised-versus-distributed-networking.md) | Centralised versus distributed networking | Accepted |
| [006](006-secrets-management.md) | Secrets management | Accepted |
| [007](007-developer-platform-cli.md) | Developer platform CLI | Accepted |
| [008](008-observability-architecture.md) | Observability architecture | Accepted |
| [009](009-build-versus-buy-developer-portal.md) | Build versus buy developer portal | Accepted |
| [010](010-reliability-and-failure-testing.md) | Reliability and failure testing | Accepted |

New ADRs take the next number. Do not rewrite history. Supersede instead.
