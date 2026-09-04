# Gap assessment (M0-M8)

This is the intended mission sequence against the **current tree on
`main`’s descendant branch**, not a plan to copy archive history.

`origin/main` at Milestone 0 start: `1407188077d1ce05eccfc03e9354b8ea951b67fd`
(`README.md` + `LICENSE` only). Closed refs: M0 `5967465` / `c0ffc86`;
M1 `eabe8872` / `240d6a6`; M2 `21c9edba` / `3743fc27`; M3 `1cbcb4d5` /
`cb108a2d`. This PR is Milestone 4.

Archive refs (do **not** copy, merge, or check out as a working base):

* `recover/aws-vertical-slice-2026-08-18` → `81cac81290af1e82c19c013a2e168fa3ceecbfd9`
* `recover/aws-ci-fixes-2026-08-18` → `23c7744f68bf2a0cc05e42dfe76b4151fac4b7f2`

Those branches preserve prior work. They are not a backlog.

| Milestone | Intent | Current tree | Gap |
| --- | --- | --- | --- |
| M0 Governance and inventory | Honest claims, ADRs (including agent operating model), `make help`/`doctor`, CI denylist, frictionctl pin+verify, SHA-pinned CI | Merged on `main` (PR #1); checkout pin on `main` (PR #2) | Closed. Do not add AWS code; do not restore archive trees |
| M1 Platform contract and CLI | Versioned WorkloadContract schema; `platform` CLI `doctor`/`validate`/`create` without cloud credentials | Merged/closed on `main` (`eabe8872` / `240d6a6`; `api/`, `cmd/platform`, `templates/` Helm skeleton, `testdata/`, `go.mod`, ADR-0008) | Closed. Kind remains WorkloadContract; Helm skeleton stays; no AWS, no GitOps apply, no journeys |
| M2 AWS foundations (local validate) | Terraform for bootstrap/network/workload with **no** Kubernetes objects; `terraform validate` without credentials | Closed on `main` (`21c9edba` / `3743fc27`; `infra/aws/bootstrap`, `infra/aws/network`, `infra/aws/workload`) locally validated without AWS credentials (init still downloads the locked provider). It does not prove AWS runtime behaviour | Pod Identity is declared but non-operational (no worker nodes and no pods). No live proof. Journeys remain unproved |
| M3 GitOps bootstrap | Argo CD apps for cluster desired state only | Closed on `main` (`1cbcb4d5` / `cb108a2d`; `gitops/` bootstrap namespaces, AppProjects `bootstrap` and `platform`, Application `gitops-root`, committed kubeconform schemas, `make gitops-validate`). Syntactic and offline only | No live cluster, no synced app, no journey. Terraform must not grow Helm/Kubernetes resources |
| M4 Helm golden path | One Helm chart reconciled by Argo CD; no second Kustomize workload set | This PR (Application `sample` under `gitops/apps/`, project `platform`, path `templates`, destination `apps`; AppProject hardening; pinned Helm lint/template; twenty named negative fixtures). Syntactic and offline only | No live Argo sync, no workload run, no operational Pod Identity, no journeys. Chart under `templates/` consumed unchanged |
| M5 Observability contract | OTel/Prometheus rules as designed, locally lintable | Absent | Not started |
| M6 Reliability and security proofs | Policy fixtures that fail closed; failure-lab write-ups | Absent (`policies/`, `tests/`, `evidence/` not in M1) | Not started |
| M7 Friction journeys proved | `frictionctl run` / `compare` against the real golden path | Pin + module-sum verify only; `journeys_proved: false` | Journeys cannot be honest until a live path exists |
| M8 Azure/GCP native parity | Provider-native depth after AWS local-validate exists | Absent by design (no Azure/GCP specialist) | Not LCM modules; not M1 |

## Explicit non-goals until a later authorised milestone

Azure/GCP implementation, Backstage, Crossplane, a service mesh, AI
control planes, live Terraform/OpenTofu apply, Graphite, `frictionctl`
journey proof, and any merge of `recover/*` onto `main`.
