# Platform Engineering Reference Architecture

> A practical reference implementation for building and operating modern
> engineering platforms across AWS, Azure and Google Cloud.

This repository shows how a capable engineering organisation can give
application teams a consistent developer experience without pretending the
three cloud providers are the same product with different logos.

It covers cloud architecture, platform engineering, Kubernetes, networking,
security, reliability, observability, GitOps, developer experience, FinOps
and technical governance.

**Build capability, not dependency.** The platform provides golden paths for
the common case and explicit escape hatches for the rest. It does not attempt
to hide AWS, Azure and Google Cloud behind a lowest-common-denominator
abstraction.

This is a reference, not a product you apply blindly. Terraform,
Kubernetes and CI in this repository are real enough to format,
validate, lint and test without cloud credentials. The AWS vertical
slice is deployable into a real estate once account IDs and CIDRs are
filled. That apply is not proved in this repository's CI.

## What this is

A production-shaped foundation for a multi-cloud engineering platform:

* AWS Organizations-style landing zone concepts, implemented deepest
* First-class Azure and GCP architectures using native services
* A shared Kubernetes platform targeting EKS, AKS and GKE
* Argo CD GitOps from commit to cluster
* A small Go developer CLI (`platform create service`)
* A sample API used to prove the path, not to show off microservices
* Observability, FinOps, security scanning and a failure-lab

## What this is not

* A tutorial, certification lab or collection of toy Terraform examples
* A claim that multi-cloud is inherently desirable
* A wrapper that makes AWS, Azure and GCP look identical
* A reason to put everything on Kubernetes
* Production-ready for your organisation without adapting account structure,
  identity, networking and operational ownership

If a hiring manager reads this and concludes "this person has operated
platforms, and knows where they fail", the repository has done its job.

## Architecture overview

```mermaid
flowchart TB
  subgraph developers [Application teams]
    Dev[Engineer]
    CLI["platform CLI"]
    Git[Application Git repo]
  end

  subgraph ci [CI]
    Test[Tests]
    Scan[Security scans]
    Build[Image build]
    SBOM[SBOM and signing]
    Registry[Container registry]
  end

  subgraph gitops [GitOps]
    Desired[Desired state in Git]
    Argo[Argo CD]
  end

  subgraph clusters [Kubernetes]
    EKS[AWS EKS]
    AKS[Azure AKS]
    GKE[Google GKE]
  end

  Dev --> CLI
  CLI --> Git
  Git --> Test --> Scan --> Build --> SBOM --> Registry
  Registry --> Desired
  Desired --> Argo
  Argo --> EKS
  Argo --> AKS
  Argo --> GKE
```

Cloud foundations sit underneath the clusters. They are not interchangeable.

```mermaid
flowchart LR
  subgraph aws [AWS]
    Orgs[Account IDs supplied externally]
    Net[Network account / TGW]
    Wl[Workload account / EKS]
    Orgs --> Net --> Wl
  end

  subgraph azure [Azure]
    MG[Management Groups]
    Entra[Entra ID]
    Hub[Hub and spoke / Virtual WAN]
    AKS2[AKS]
    MG --> Entra --> Hub --> AKS2
  end

  subgraph gcp [GCP]
    Folders[Org, folders, projects]
    IAM[Cloud IAM]
    SVPC[Shared VPC / NCC]
    GKE2[GKE]
    Folders --> IAM --> SVPC --> GKE2
  end

  K8s[Common Kubernetes and GitOps layer]
  Wl --> K8s
  AKS2 --> K8s
  GKE2 --> K8s
```

The portability boundary is Kubernetes plus a common developer workflow. It
is not Terraform modules with the serial numbers filed off. See
[ADR-003](docs/decisions/003-kubernetes-abstraction-boundary.md) and
[ADR-004](docs/decisions/004-multi-cloud-strategy.md).

## Core principles

1. Prefer boring, proven technology over unnecessary novelty.
2. Automate repeatable work.
3. Make the secure path the easiest path.
4. Git is the source of truth for platform configuration.
5. Use short-lived credentials rather than permanent cloud access keys.
6. Infrastructure must be reproducible.
7. Platforms should reduce cognitive load for application teams.
8. Observability must be designed in rather than bolted on later.
9. Reliability is a measurable engineering property.
10. Cloud portability should exist at sensible abstraction boundaries.
11. Do not create a lowest-common-denominator multi-cloud platform.
12. Prefer provider-native capabilities where they materially improve the platform.
13. Architecture decisions should explicitly document trade-offs.
14. Cost is an architectural concern.
15. Golden paths should cover roughly 80% of normal engineering use cases,
    with explicit escape hatches for the rest.

Detail: [docs/principles](docs/principles/README.md).

## Supported cloud providers

| Provider | Depth in this commit | Native centre of gravity |
| --- | --- | --- |
| AWS | Network + workload accounts, TGW routing, EKS, ECR, OIDC, GitOps | Organizations, IAM Identity Center, Transit Gateway |
| Azure | Architecture, hub-and-spoke / Virtual WAN, AKS skeleton | Management Groups, Entra ID, Azure Policy |
| GCP | Architecture, Shared VPC / NCC, GKE skeleton | Folders, projects, Shared VPC, Workload Identity |

AWS is the deepest implementation because that is how most enterprises
actually start. Azure and GCP are not afterthoughts. They use different
identity, networking and policy primitives on purpose.

## Developer workflow

```text
platform create service payments-api
git push
CI: test, scan, build, SBOM, sign
GitOps: Argo CD syncs Helm to EKS / AKS / GKE
```

The CLI currently scaffolds a Go service with Dockerfile, Helm chart,
GitHub Actions, ownership metadata, a default SLO and a runbook stub. It
does not provision cloud accounts. That remains a platform-team change.

## Platform capabilities

Statuses are honest. **Implemented** means the code exists.
**Locally proved** means `make verify-aws` (or equivalent) passes.
**Live proved** means it has been applied and traffic-tested in AWS.
Nothing in this repository is live proved by CI.

| Capability | Status |
| --- | --- |
| AWS network account | Implemented, locally proved |
| AWS workload account | Implemented, locally proved |
| Transit Gateway routing | Implemented, locally proved |
| EKS | Implemented, locally proved |
| ECR | Implemented, locally proved |
| GitHub OIDC | Implemented, locally proved |
| Argo CD | Implemented, not live proved |
| Sample workload | Implemented, locally proved |
| Observability (rules, dashboard, alerts) | Implemented, locally proved |
| Workload identity (Pod Identity) | Implemented, locally proved |
| Secrets Manager + ESO contract | Implemented, locally proved |
| Security policy proof | Implemented, locally proved |
| Pod / bad deploy / NetworkPolicy / node drain tests | Implemented, not live proved |
| Real AWS apply | Not proved |
| Live traffic verification | Not proved |
| Azure and GCP equivalent architectures | Documented, Terraform skeletons |
| Developer portal UI | Explicitly deferred, see ADR-009 |

## Repository structure

```text
docs/                  principles, ADRs, architecture, operating model
landing-zones/         AWS, Azure, GCP organisational design
terraform/             modules and compositions, one tree per provider
kubernetes/            base + provider overlays
gitops/                Argo CD bootstrap and environment apps
developer-platform/    CLI, golden paths, templates
examples/              sample-service and later consumers
security/              IAM, policy-as-code, supply chain, threat models
observability/         OpenTelemetry, Prometheus, Grafana, SLOs
resilience/            failure-lab, DR, game days
finops/                cost models, budgets, tagging
networking/            provider-native and multi-cloud notes
```

## Quick start

You do not need cloud credentials to validate this repository.

```bash
git clone <this-repo>
cd platform-engineering-reference
make init
make lint
make test
make validate
make security
```

Build the sample service and CLI:

```bash
make build
./bin/platform version
./bin/platform doctor
./bin/platform create service demo-api --dry-run
```

Plan infrastructure only with an explicit provider and environment:

```bash
make plan PROVIDER=aws ENVIRONMENT=dev STACK=network
make verify-aws
```

There is no default `make deploy`. AWS apply requires `STACK` and
`CONFIRM=yes`. Destruction requires `PROVIDER`, `ENVIRONMENT` and, on
AWS, `STACK`.

## Current implementation status

Honest status, not a badge board:

* **Ready to read and debate:** architecture, principles, ADRs, operating
  model, Northstar Rail migration case study.
* **Ready to validate locally:** `make verify-aws`, Terraform tests, Go
  tests, Helm lint, policy fixtures.
* **Ready to apply with your account IDs:** the AWS bootstrap, network
  and workload stacks. Not proved against a live organisation in CI.
* **Planned:** Azure/GCP depth, hub egress, organisation-wide security
  admin, Kyverno.

See [docs/aws/deployment.md](docs/aws/deployment.md).

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md). The next useful increment is a
live apply of this AWS slice plus Azure brought to the same depth.

## Design decisions

ADRs live in [docs/decisions](docs/decisions/README.md). Start with
Terraform (001), Argo CD (002), the Kubernetes boundary (003) and
multi-cloud strategy (004).

## Security

Security is a platform property, not a specialist add-on. CI rejects
insecure IaC fixtures on purpose. Read [SECURITY.md](SECURITY.md) and
[docs/security](docs/security/README.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Small, tested changes beat large
aspirational ones.

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
