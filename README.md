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
* agent operating model (Grok-only, process-isolated review; M0-M2 closed;
  M3 is one new PR)
* `make help` and `make doctor`
* `make platform-test` (Go tests plus CLI positive/negative checks)
* `platform doctor`, `platform validate`, and `platform create` (local CLI)
* a WorkloadContract JSON Schema with valid and invalid fixtures
* one Helm chart skeleton under `templates/` (files on disk, not a deploy)
* `make terraform-validate` for the three `infra/aws/` roots (fmt, init
  without a backend, validate; AWS credentials unset)
* `make gitops-validate` for `gitops/` (kustomize render, kubeconform with
  committed local schemas, field-level semantic checks)
* CI denylist so Terraform state and keys cannot be tracked unnoticed by CI
* a recorded pin for `frictionctl` module tag `v0.1.0` with Go module sums
  verified (`frictionctl version` is exactly `0.1.0`; journeys are **not**
  proved)

That is all. No live cluster, no applied account, no synced Argo CD app,
no live workload path, no live traffic.

## What runs locally

```bash
make help && make doctor
make check-prohibited
make platform-test
make terraform-validate
make gitops-validate
make friction-pin-verify
```

`make help` lists the real targets. `make doctor` checks required local
tools (`git`, `make`). It does not call AWS. It does not need credentials.
`platform doctor` additionally requires `go`. It succeeds with AWS
credential environment variables unset. It does not call AWS.
`make platform-test` runs `go test ./...` and CLI positive/negative checks.
`make terraform-validate` does not need AWS credentials. `terraform init
-backend=false` still downloads the locked AWS provider.
`make gitops-validate` may install pinned kustomize and kubeconform over
the network, then validates only from committed files. It does not apply,
does not call kubectl, and does not talk to a cluster.
`make friction-pin-verify` uses `go mod download -json` (not a sumdb curl)
and does not run journeys.

CI on pull requests runs those gates, `make platform-test`, a negative
doctor case, the prohibited-path stdin0 suite, targeted operating-model
assertions, `make terraform-validate`, `make gitops-validate`, and a
Gitleaks scan. CI does not apply Terraform and does not apply GitOps.

## What costs money

Nothing yet. Terraform and GitOps files exist as desired state on disk.
There is no apply target. Cost starts when someone applies AWS resources
on purpose in a later, authorised step.

## Designed versus proved

| Item | Status |
| --- | --- |
| Product claims and gap assessment | Written; locally readable |
| ADRs for source of truth, ownership, AWS-first, Helm-only golden path, exclusions, frictionctl pin, agent operating model, platform contract and CLI, AWS foundations roots, GitOps bootstrap | Written (0001-0005 remain Accepted; 0010 is this milestone) |
| `make help` / `make doctor` | Locally proved |
| `platform doctor` / `platform validate` / `platform create` | Locally proved when those commands are run |
| WorkloadContract schema and fixtures | Locally proved by `go test` and `platform validate` |
| Helm chart skeleton under `templates/` | Files on disk; not a deploy; not live proved |
| `infra/aws` Terraform roots | Locally proved by `make terraform-validate`; not live proved |
| GitOps bootstrap under `gitops/` | Locally proved by `make gitops-validate`; not live proved; `gitops/apps` has no M4 Application |
| Tracked-file denylist in CI | Locally runnable; CI-asserted |
| Secret scan in CI | Designed to run on GitHub; not a live-cloud proof |
| frictionctl v0.1.0 pin + module-sum verify | Recorded and verifiable; journeys not proved |
| Live AWS apply, synced Argo CD, sample workload traffic | Not proved; not in this milestone |
| Azure/GCP parity | Not proved; not in this milestone |

See [docs/product/claims-matrix.md](docs/product/claims-matrix.md).

## Deliberately not included

* Restore or copy of `recover/*` archive trees (`81cac81`, `23c7744`)
* Recreating missing commit `3522e48`
* A parallel Kustomize workload set for the Helm golden path
* Azure or GCP modules
* Backstage, Crossplane, a service mesh, or AI control planes
* Graphite, `frictionctl run` / journey proof
* Any deploy/apply/destroy Make target
* Auto-sync on Application `gitops-root`
* Milestone 4 Applications under `gitops/apps/`

Archive branches `recover/aws-vertical-slice-2026-08-18` and
`recover/aws-ci-fixes-2026-08-18` are **archive only**. They are not a
working base and not a backlog to copy.

## Shortest demo

```bash
git clone <this-repo>
cd platform-engineering-reference
make help && make doctor
go run ./cmd/platform doctor
go run ./cmd/platform validate testdata/workloadcontract-valid.yaml
make platform-test
make gitops-validate
```

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
