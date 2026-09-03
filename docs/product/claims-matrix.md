# Claims matrix

Statuses are honest. **Designed** means the law or layout is written.
**Locally proved** means a command in this repository was run without
cloud credentials. **Live proved** means applied and traffic-tested in
AWS. Nothing in Milestone 0 is live proved.

Owner for every current claim is the lead builder (integration owner).

| Claim ID | User outcome | Scope | Status | Implementation paths | Positive test | Negative test | Evidence | Limitations | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-000 | A clean checkout documents what is and is not proved | README, this matrix, gap assessment | Locally proved (documentation) | `README.md`, `docs/product/claims-matrix.md`, `docs/product/gap-assessment.md` | README states nothing is live; shortest demo is `make help && make doctor` | README must not claim this repo is production-ready | File contents on this branch | Documentation can drift; re-read on every milestone | Lead builder |
| GOV-001 | Ownership and ADR law exist | `docs/adr/` | Locally proved (files present and indexed) | `docs/adr/README.md`, `docs/adr/0001`–`0006` | Index lists six ADRs; each has context, decision, consequences, rejected options, review trigger | Missing ADR for a binding control-plane choice | ADR files in this PR | Law is not enforced by a policy engine yet | Lead builder |
| GOV-002 | `make doctor` / `make help` exist and fail usefully | Makefile | Locally proved when those targets are run | `Makefile` | `make help` exits 0 and lists `help` and `doctor` | `make not-a-target` fails; `make doctor REQUIRED_TOOLS='git make definitely-not-a-tool'` prints `missing: definitely-not-a-tool` | Command output in the hand-off | Doctor checks local binaries only, not repository completeness of later milestones | Lead builder |
| GOV-003 | Secrets and Terraform state cannot be committed unnoticed | Ignore rules + CI secret scan | Locally proved for `.gitignore`; CI scan designed and implemented in workflow | `.gitignore`, `.github/workflows/ci.yml` | `.gitignore` includes `*.tfstate`, `*.pem`, `.env`, `kubeconfig`, credentials; workflow runs Gitleaks | Workflow file contains no `terraform apply` | File contents; CI run on the PR | Gitleaks cannot catch every secret form; humans can still force-add ignored files | Lead builder |
| FRIC-000 | frictionctl v0.1.0 pin recorded; journeys not yet proved | `.friction/` | Pin recorded; journeys **not** proved | `.friction/pin.yml`, `.friction/README.md`, ADR-0006 | Pin lists module, `v0.1.0`, and commit `79398cfb55bcc253045bb0065a342a8fe805549a` | No journey YAML that claims a golden-path SLO | Pin file versus GitHub tag `v0.1.0` | `frictionctl` is not run as a gate in Milestone 0 | Lead builder |

## Blockers (not claims of presence)

| ID | What it is | Status | What we do not do |
| --- | --- | --- | --- |
| `3522e48` | A commit SHA that was requested during inspection and was not found on any ref, tag, stash, reflog, or GitHub | **Missing** | Do not recreate it. Do not treat archive tips `81cac81` or `23c7744` as a substitute. |
