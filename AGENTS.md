# AGENTS.md

Instructions for humans and coding agents working on this repository.

## Product

This is a platform engineering **reference**, not a live estate. Milestone 0
is governance on empty `main` (`1407188`). Nothing is live-proved. Do not
claim production-ready status.

## Integration owner

The **lead builder** (the main Cursor agent implementing a milestone) is
the integration owner and the only writer unless a follow-up names a
delegate. Specialists inspect, propose, or implement within path
ownership. They do not merge, apply Terraform, or open extra PRs unless
asked.

## Six agents

| Agent | Role | Write? | Path ownership |
| --- | --- | --- | --- |
| `architecture-reasoning` | Architecture gate before boundary or ADR changes | Read-only | none |
| `platform-product-builder` | Claims, README, gap assessment, product docs | Write | `README.md`, `docs/product/`, `AGENTS.md` (product text only) |
| `aws-platform-builder` | AWS foundations later | Write when authorised | future `infra/aws/` only; **stop in M0** |
| `reliability-security-builder` | Ignore rules, secret scan, friction pin, later policy proofs | Write | `.gitignore`, `.github/workflows/`, `.github/dependabot.yml`, `.friction/`, later `policies/` `tests/` `evidence/` |
| `multicloud-parity-builder` | Azure/GCP native parity later | Write when authorised | future `infra/azure/`, `infra/gcp/`; **stop until M8** |
| `independent-reviewer` | Falsify claims after implementation | Read-only | none |

Definitions live in `.cursor/agents/`.

## Routing

1. Inspect `HEAD`, allowed paths, and ADRs.
2. Invoke `architecture-reasoning` before adding or changing ADRs,
   ownership, or milestone scope.
3. Lead builder writes the milestone (this M0 set).
4. Route path-shaped follow-ups to the matching builder; they must refuse
   forbidden paths.
5. Invoke `independent-reviewer` before claiming completion.
6. Hand off with the format below. Do not merge unless the user says so.

## Write boundaries (Milestone 0)

Allowed: `README.md`, `AGENTS.md`, `Makefile`, `.gitignore`,
`.github/workflows/`, `.github/dependabot.yml`, `.cursor/agents/`,
`docs/adr/`, `docs/product/`, `.friction/`. Do not change `LICENSE`.

Forbidden: `infra/`, `terraform/`, `landing-zones/`, `gitops/`,
`kubernetes/`, `examples/`, `developer-platform/` copied from archive;
checkout/cherry-pick/copy of `81cac81` or `23c7744`; recreating `3522e48`;
Azure/GCP modules; Backstage; Crossplane; mesh; AI; `terraform apply`;
empty directories with no file; overlapping Terraform and GitOps objects.

`recover/*` is archive only.

## Review gates

* `architecture-reasoning` before ADR or control-plane changes.
* `make help` and `make doctor` (no cloud credentials).
* Secret scan in CI; no Terraform apply in CI.
* `independent-reviewer` before done.
* Claims in `docs/product/claims-matrix.md` must match commands actually run.

## Hand-off format

Return exactly these headings to the **lead builder**:

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
cloud credentials required; overlapping Terraform/GitOps in the PR.
