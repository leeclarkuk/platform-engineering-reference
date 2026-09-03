# Claims matrix

Statuses are honest. **Designed** means the law or layout is written.
**Locally proved** means a command in this repository was run without
cloud credentials. **Live proved** means applied and traffic-tested in
AWS. Nothing in Milestone 0 is live proved.

Owner for every current claim is the Chief of Staff (integration owner).

| Claim ID | User outcome | Scope | Status | Implementation paths | Positive test | Negative test | Evidence | Limitations | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-000 | A clean checkout documents what is and is not proved | README, this matrix, gap assessment | Locally proved (documentation) | `README.md`, `docs/product/claims-matrix.md`, `docs/product/gap-assessment.md` | README states nothing is live; shortest demo is `make help && make doctor` | README must not claim this repo is production-ready | File contents on this branch | Documentation can drift; re-read on every milestone | Chief of Staff |
| GOV-001 | Ownership and ADR law exist | `docs/adr/`, `AGENTS.md` | Locally proved (files present and indexed) | `docs/adr/README.md`, `docs/adr/0001`–`0007`, `AGENTS.md` | Index lists seven ADRs; 0001–0005 stay Accepted; 0007 records the Lee-approved agent operating model | Missing ADR for a binding control-plane or operating-model choice | ADR files in this PR | Law is not enforced by a policy engine yet | Chief of Staff |
| GOV-002 | `make doctor` / `make help` exist and fail usefully | Makefile | Locally proved when those targets are run | `Makefile` | `make help` exits 0 and lists `help`, `doctor`, `check-prohibited`, `friction-pin-verify` | `make not-a-target` fails; `make doctor REQUIRED_TOOLS='git make definitely-not-a-tool'` prints `missing: definitely-not-a-tool` and exits non-zero | Command output in the hand-off and CI | Doctor checks local binaries only, not repository completeness of later milestones | Chief of Staff |
| GOV-003 | Prohibited secrets and Terraform state cannot be tracked unnoticed by CI | Tracked-file denylist + CI assertions + Gitleaks | Locally proved for the denylist script; CI asserts exit codes and messages | `scripts/check-prohibited-tracked.sh`, `Makefile`, `.github/workflows/ci.yml`, `.gitignore` | Default `git ls-files` tree exits 0; `printf 'secret.tfstate\0' \| scripts/check-prohibited-tracked.sh --stdin0` is non-zero and prints `PROHIBITED:` | `.env.example` and `safe.tfvars.example` exit 0; `production.tfvars`, `nested/path/id_rsa`, and a prohibited name with spaces are non-zero. Unexpected script errors without `PROHIBITED:` do not count as rejection | CI stdin0 suite; workflow on this PR | Humans can still force-add files if CI is skipped; Gitleaks cannot catch every secret form. Ignore rules are defence in depth, not the GOV-003 proof | Chief of Staff |
| GOV-004 | Agent operating model is Grok-only, process-isolated, single PR | `AGENTS.md`, `.cursor/agents/`, ADR-0007 | Locally proved (files and targeted assertions) | `AGENTS.md`, `.cursor/agents/*.md`, `docs/adr/0007-agent-operating-model.md` | `make check-m0-assertions` exits 0 | Retired agent files must not exist; dormant AWS/GitOps builders refuse M0 writes | Targeted assertion output | Review with Opus remains debt (`REVIEW_DEBT: RECHECK_WITH_OPUS_WHEN_AVAILABLE`) | Chief of Staff |
| FRIC-000 | frictionctl v0.1.0 pin recorded and module sums verified; journeys not proved | `.friction/` | Pin recorded and verify command locally/CI proved; journeys **not** proved | `.friction/pin.yml`, `.friction/README.md`, ADR-0006, `scripts/friction-pin-verify.sh` | Isolated `go mod download -json` `Sum`/`GoModSum` equal pin `sum`/`gomod_sum`; `test "$(frictionctl version)" = "0.1.0"` | Curling sumdb is not proof; executable must not be accepted via substring; no journey YAML that claims a golden-path SLO | `make friction-pin-verify` output | `frictionctl run` is not a gate in Milestone 0 | Chief of Staff |

## Blockers (not claims of presence)

| ID | What it is | Status | What we do not do |
| --- | --- | --- | --- |
| `3522e48` | A commit SHA that was requested during inspection and was not found on any ref, tag, stash, reflog, or GitHub | **Missing** | Do not recreate it. Do not treat archive tips `81cac81` or `23c7744` as a substitute. |
