# ADR-0001: Empty main is the source of truth; recover branches are archive only

- Status: Accepted
- Date: 2026-09-03

## Context

GitHub `main` was force-updated to `1407188077d1ce05eccfc03e9354b8ea951b67fd`
(`Initial commit`, `README.md` + `LICENSE`). Lee confirmed that empty main
is intentional. Prior platform files remain reachable only on
`recover/aws-vertical-slice-2026-08-18` (`81cac81`) and
`recover/aws-ci-fixes-2026-08-18` (`23c7744`). Commit `3522e48` was not
found and must not be recreated.

## Decision

Implementation happens on descendants of `1407188`. `recover/*` are archive
refs. Do not merge, cherry-pick, check out as a working base, or copy those
trees into `infra/`, `terraform/`, `landing-zones/`, `gitops/`,
`kubernetes/`, `examples/`, or `developer-platform/`.

## Consequences

* Milestone 0 is governance on the empty-main lineage, not a restore.
* Archive may be read for failure lessons (dual manifests, unpinned
  actions, overlapping ownership). Lessons are restated as new ADRs.
* Missing `3522e48` stays a blocker row, not a commit we invent.

## Rejected options

* Reset `main` to `81cac81` or merge recover into `main`.
* Recreate `3522e48`.
* Treat archive as the product backlog to copy.

## Review trigger

A request to restore archive files, to use `recover/*` as a working branch
for new milestones, or to recreate `3522e48`.
