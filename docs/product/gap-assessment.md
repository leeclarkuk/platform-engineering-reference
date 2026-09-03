# Gap assessment (M0–M8)

This is the intended mission sequence against the **current tree on
`main`’s descendant branch**, not a plan to copy archive history.

`origin/main` at Milestone 0 start: `1407188077d1ce05eccfc03e9354b8ea951b67fd`
(`README.md` + `LICENSE` only).

Archive refs (do **not** copy, merge, or check out as a working base):

* `recover/aws-vertical-slice-2026-08-18` → `81cac81290af1e82c19c013a2e168fa3ceecbfd9`
* `recover/aws-ci-fixes-2026-08-18` → `23c7744f68bf2a0cc05e42dfe76b4151fac4b7f2`

Those branches preserve prior work. They are not a backlog.

| Milestone | Intent | Current tree | Gap |
| --- | --- | --- | --- |
| M0 Governance and inventory | Honest claims, ADRs (including agent operating model), `make help`/`doctor`, CI denylist, frictionctl pin+verify, SHA-pinned CI | This PR (corrective spec on the existing branch) | Close this row in the PR; do not add AWS code; do not open a second PR |
| M1 Platform contract and CLI | Versioned contract schema; `platform` CLI `doctor`/`validate`/`create` without cloud credentials | Absent (`api/`, `cmd/`, `platform/`, `templates/` not in M0) | New work on empty-main lineage; do not copy `developer-platform/` from archive |
| M2 AWS foundations (local validate) | Terraform for bootstrap/network/workload with **no** Kubernetes objects; `terraform validate` without credentials | Absent (`infra/` forbidden in M0; `aws-foundations-builder` is dormant) | New AWS modules on this lineage; do not restore archive `terraform/` or `landing-zones/` |
| M3 GitOps bootstrap | Argo CD apps for cluster desired state only | Absent (`gitops-golden-path-builder` is dormant) | New `gitops/` later; Terraform must not grow Helm/Kubernetes resources |
| M4 Helm golden path | One Helm chart reconciled by Argo CD; no second Kustomize workload set | Absent | New `workloads/` or templates later; do not copy archive `kubernetes/base` plus Helm |
| M5 Observability contract | OTel/Prometheus rules as designed, locally lintable | Absent | Not started |
| M6 Reliability and security proofs | Policy fixtures that fail closed; failure-lab write-ups | Absent (`policies/`, `tests/`, `evidence/` not in M0) | Not started |
| M7 Friction journeys proved | `frictionctl run` / `compare` against the real golden path | Pin + module-sum verify only; `journeys_proved: false` | Journeys cannot be honest until M1–M4 exist |
| M8 Azure/GCP native parity | Provider-native depth after AWS local-validate exists | Absent by design (no Azure/GCP specialist in M0) | Not LCM modules; not M0 |

## Explicit non-goals until a later authorised milestone

Azure/GCP implementation, Backstage, Crossplane, a service mesh, AI
control planes, live Terraform/OpenTofu apply, Graphite, `frictionctl`
journey proof, and any merge of `recover/*` onto `main`.
