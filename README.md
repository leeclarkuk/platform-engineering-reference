# Platform engineering reference

A governance-first reference for building an AWS-first engineering platform.
This commit documents what exists, what is only designed, and what must not
be restored from archive history.

Nothing in this repository is live in a cloud account. Nothing here is
production-ready. There is no apply target and no cloud bill yet.

## Who this is for

Platform engineers, the Chief of Staff (integration owner), and the
Lee-authorised Grok implementation builder who will grow this tree through
numbered milestones. It is not a product you point at a live organisation.
It is not a restore of an older AWS slice.

## What this proves

On a clean checkout of this branch you can read the claims and run local
gates that need no cloud credentials:

* what is designed versus what has been run locally
* ownership law for Terraform versus Argo CD (no overlapping objects)
* agent operating model (Grok-only, process-isolated review, single PR)
* `make help` and `make doctor`
* CI denylist so Terraform state and keys cannot be tracked unnoticed by CI
* a recorded pin for `frictionctl` module tag `v0.1.0` with Go module sums
  verified (`frictionctl version` is exactly `0.1.0`; journeys are **not**
  proved)

That is all. No cluster, no account, no workload path, no live traffic.

## What runs locally

```bash
make help && make doctor
make check-prohibited
make friction-pin-verify
```

`make help` lists the real targets. `make doctor` checks required local
tools (`git`, `make`). It does not call AWS. It does not need credentials.
`make friction-pin-verify` uses `go mod download -json` (not a sumdb curl)
and does not run journeys.

CI on pull requests runs those gates, a negative doctor case, the
prohibited-path stdin0 suite, targeted operating-model assertions, and a
Gitleaks scan. CI does not run Terraform.

## What costs money

Nothing yet. There is no `infra/`, no Terraform apply, and no cloud
resource in this tree. Cost starts when a later milestone adds an AWS
slice and someone applies it on purpose.

## Designed versus proved

| Item | Status |
| --- | --- |
| Product claims and gap assessment | Written; locally readable |
| ADRs for source of truth, ownership, AWS-first, Helm-only golden path, exclusions, frictionctl pin, agent operating model | Written (0001–0005 remain Accepted) |
| `make help` / `make doctor` | Locally runnable |
| Tracked-file denylist in CI | Locally runnable; CI-asserted |
| Secret scan in CI | Designed to run on GitHub; not a live-cloud proof |
| frictionctl v0.1.0 pin + module-sum verify | Recorded and verifiable; journeys not proved |
| AWS landing zone, EKS, GitOps, sample workload | Designed only (later milestones; builders dormant in M0) |
| Live AWS apply, traffic, Azure/GCP parity | Not proved; not in this milestone |

See [docs/product/claims-matrix.md](docs/product/claims-matrix.md).

## Deliberately not included

* Restore or copy of `recover/*` archive trees (`81cac81`, `23c7744`)
* Recreating missing commit `3522e48`
* Terraform, GitOps, Kubernetes manifests, or example services
* Azure or GCP modules
* Backstage, Crossplane, a service mesh, or AI control planes
* Graphite, `frictionctl run` / journey proof
* Any deploy/apply/destroy Make target

Archive branches `recover/aws-vertical-slice-2026-08-18` and
`recover/aws-ci-fixes-2026-08-18` are **archive only**. They are not a
working base and not a backlog to copy.

## Shortest demo

```bash
git clone <this-repo>
cd platform-engineering-reference
make help && make doctor
```

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
