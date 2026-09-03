# AGENTS.md

Instructions for humans and coding agents working on this repository.

## Product

This is a platform engineering **reference**, not a live estate. Milestone 0
is governance on empty `main` (`1407188`). Milestone 1 adds a WorkloadContract
schema and a local `platform` CLI. Milestone 2 adds AWS foundations Terraform
under `infra/aws/`, validated locally without cloud credentials. Milestone 3
adds GitOps bootstrap under `gitops/`, validated locally without a cluster.
Nothing is live-proved. Do not claim production-ready status.

Immutable closed refs (do not rewrite that evidence):

* Milestone 0: `5967465` / `c0ffc86`
* Milestone 1: `eabe8872` / `240d6a6`
* Milestone 2: `21c9edba` / `3743fc27`

## Integration owner

The **Chief of Staff** is the sole coordinator and integration owner.
There is no second Chief of Staff. Specialists inspect, propose, or
implement within path ownership. They do not merge, apply Terraform, or
open extra pull requests.

The implementation builder writes only after a Lee-approved spec. The
Milestone 0 single-PR rule is closed (PR #1 merged). Milestone 1 is closed
on `main` (PR #3). Milestone 2 is closed on `main` (PR #4). Milestone 3 is
this one new pull request. Do not open a second PR for this layer. Do not
merge without Lee.

`platform-product-builder` owns the authorised Milestone 1
implementation paths listed in the team table. It does **not** own
`AGENTS.md`, `.cursor/agents/`, Makefile integration, or
`.github/workflows/`.

## Model policy

```text
MODEL_MODE: GROK_ONLY_AUTHORISED_BY_LEE
REVIEW_INDEPENDENCE: PROCESS_ISOLATED_NOT_MODEL_DIVERSE
REVIEW_DEBT: RECHECK_WITH_OPUS_WHEN_AVAILABLE
CONTEXT_MODE: FRESH
```

Lee authorised Grok as the implementation model for this work. Review
independence is process isolation (fresh context, named reviewer, hashed
input bundle), not a second model family. Recheck with Opus when that
reviewer is available. Public visibility is not a finding. Do not treat a
fallback as the operating mode.

## Team

| Agent | Role | Write? | Path ownership |
| --- | --- | --- | --- |
| `specification-architect` | Spec-first architecture gate before implementation | Read-only | none |
| `platform-product-builder` | Claims, README, gap assessment, and authorised M1 implementation | Write | `api/`, `cmd/`, `internal/`, `templates/`, `testdata/`, `go.mod`, `go.sum`, `README.md`, `docs/product/` (not `AGENTS.md`, `.cursor/agents/`, `Makefile`, or `.github/workflows/`) |
| `aws-foundations-builder` | AWS foundations (Milestone 2, closed) | Write | `infra/aws/` only |
| `gitops-golden-path-builder` | GitOps bootstrap (Milestone 3) | Write | `gitops/` only |
| `reliability-security-reviewer` | Process-isolated review of ignore rules, pin, CI, secrets | Read-only | none |
| `evidence-adversarial-reviewer` | Falsify claims without the other reviewer's verdict | Read-only | none |

Definitions live in `.cursor/agents/`. Azure/GCP specialist work and
Graphite are out of scope. Helm files under `templates/` in Milestone 1 are
a chart skeleton on disk, not a GitOps apply. Milestone 3 does not start
Milestone 4 and does not add an Application under `gitops/apps/`.

## Workflow

1. `/goal` is spec-first. Invoke `specification-architect` before adding
   or changing ADRs, ownership, or milestone scope. Do not implement first.
2. Lee approval is required before implementation.
3. After approval, Milestone 3 is this one new pull request. Do not open
   a second PR. Do not retarget, rebase onto a new branch, or merge unless
   the user says so.
4. Bounded `/swarm` may fan out specialists inside path ownership. Swarm
   members must refuse forbidden paths. The AWS foundations builder remains
   limited to `infra/aws/` and must not modify Terraform in this
   milestone. The GitOps builder is active for Milestone 3 and writes only
   under `gitops/`.
5. `/loop` is verification-only. If a check fails, make the smallest
   correction and rerun. Stop after three unsuccessful attempts.

## Write boundaries (Milestone 3)

Allowed: `README.md`, `AGENTS.md`, `Makefile`, `.gitignore`,
`.github/workflows/`, `.github/dependabot.yml`, `.cursor/agents/`,
`docs/adr/`, `docs/product/`, `.friction/`, `scripts/`, `api/`, `cmd/`,
`internal/`, `templates/`, `testdata/`, `go.mod`, `go.sum`, `infra/aws/`,
`gitops/`. Do not change `LICENSE`. Do not stage secret files in the
repository. Do not modify `infra/aws` Terraform, `api/`, `cmd/`,
`templates/`, or the WorkloadContract in this pull request.

Forbidden: `infra/` except existing `infra/aws/` (do not edit those
roots here), `terraform/`, `landing-zones/`, `kubernetes/` (except Helm
files under `templates/`), `examples/`, `developer-platform/` copied from
archive; checkout/cherry-pick/copy of `81cac81` or `23c7744`; recreating
`3522e48`; Azure/GCP modules; Backstage; Crossplane; mesh; AI; runnable
Terraform/OpenTofu apply or destroy; `kubectl apply`; Helm
install/upgrade; Argo CD mutation; AWS API; empty directories with no
file; overlapping Terraform and GitOps objects; Graphite; `frictionctl run`
/ journey proof; Milestone 4 Applications under `gitops/apps/`.

`recover/*` is archive only.

The AWS foundations builder must refuse writes outside `infra/aws/`.
The GitOps builder is active for Milestone 3 and must refuse writes
outside `gitops/`.

## Review gates

* Spec and Lee approval before implementation.
* `make help`, `make doctor`, `make check-prohibited`,
  `make friction-pin-verify` (no cloud credentials).
* `make platform-test` (`go test ./...` plus CLI positive/negative
  checks; `platform doctor` with AWS credential env unset).
* `make terraform-validate` (fmt, boundary and trust checks, then
  `terraform init -backend=false -lockfile=readonly` and
  `terraform validate` for the three `infra/aws/` roots, AWS credentials
  unset). Init still downloads the locked AWS provider; this is not
  air-gapped.
* `make gitops-validate` (fail closed if committed schemas are missing
  or empty; `kustomize build gitops` and `gitops/apps`; kubeconform on
  those renders using only `-schema-location` under `gitops/schemas/`
  with remote schema locations disabled; `scripts/check-gitops-semantics.sh`
  parsing YAML field-level and executing fixtures under
  `testdata/gitops-boundaries/`). Tool installation may use the network.
  Validation does not. AWS credentials unset.
* Secret scan in CI. Executable files under `.github/workflows/`,
  `Makefile`, and `scripts/` must not contain runnable Terraform/OpenTofu
  apply or destroy, `kubectl apply`, or Helm install/upgrade.
* Process-isolated reviews: `reliability-security-reviewer` and
  `evidence-adversarial-reviewer` in fresh context. The evidence reviewer
  must not receive the reliability-security verdict.
* Claims in `docs/product/claims-matrix.md` must match commands actually
  run.

## Process-isolated review hand-off

Reviewers return exactly these fields, plus evidence. Do not reuse a
builder transcript as the review context.

```text
REVIEWER
MODEL
AGENT_RUN_ID
CONTEXT_MODE: FRESH
INPUT_BUNDLE_SHA256
REPOSITORY_HEAD
VERDICT
```

`VERDICT` is `PASS`, `PASS_WITH_CONDITIONS`, or `DENY`. Any Blocker or High finding must produce `DENY`. `INPUT_BUNDLE_SHA256` hashes the files
and command outputs given to that reviewer. `REPOSITORY_HEAD` is the
commit actually reviewed.

Builders may also return:

```text
SUMMARY
BRANCH
FILES
CLAIMS
COMMANDS
RESULTS
NEGATIVE RESULTS
EVIDENCE
ADRS
SECURITY/COST
LIMITATIONS
BLOCKERS
INTEGRATION NOTES
```

## Stop conditions

Dirty unrelated files; urge to copy archive trees; recreating `3522e48`;
cloud credentials required; overlapping Terraform/GitOps in the PR;
opening a second pull request; AWS foundations builder writing outside
`infra/aws/`; GitOps builder writing outside `gitops/`; three
consecutive failed verification loops.
