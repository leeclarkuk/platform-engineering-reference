# ADR-0007: Agent operating model

- Status: Accepted
- Date: 2026-09-03

## Context

Milestone 0 needs a binding operating model for humans and coding agents
before any AWS or GitOps tree exists. The first PR drafted a six-agent
roster that mixed builders and reviewers, allowed product docs to own
`AGENTS.md`, and described review as if a second model family were
present. Lee approved a corrective specification: Grok is the authorised
implementation model, Chief of Staff is the sole coordinator, review is
process-isolated rather than model-diverse, and Opus recheck is recorded
as debt.

Public visibility of a pull request is not a finding. A fallback is not
the operating mode.

## Decision

Accepted because Lee approved this specification.

* `/goal` is spec-first. `specification-architect` is read-only. Lee
  approval is required before implementation.
* After approval, work stays on the existing pull request (one pstack
  layer). Do not open a second PR.
* Bounded `/swarm` may fan out specialists inside path ownership.
  `/loop` is verification-only and stops after three unsuccessful
  attempts.
* Implementation model: Grok only, authorised by Lee.
* Review independence: process isolation (fresh context, named reviewer,
  hashed input bundle, repository head, verdict). It is not
  model-independent review.
* Review debt: recheck with Opus when that reviewer is available.
* Chief of Staff is the sole coordinator. There is no second Chief of
  Staff. `platform-product-builder` does not own `AGENTS.md`.
* The living roster is: `specification-architect` (read-only),
  `platform-product-builder`, `aws-foundations-builder` (dormant in M0),
  `gitops-golden-path-builder` (dormant in M0),
  `reliability-security-reviewer` (read-only),
  `evidence-adversarial-reviewer` (read-only; runs without the
  reliability-security verdict).
* Dormant AWS and GitOps builders refuse Milestone 0 writes. Azure/GCP
  specialist work, Graphite, archive restore, and live apply are out of
  scope.

## Consequences

* Agent definition files under `.cursor/agents/` match the roster above.
  Retired names (`architecture-reasoning`, `independent-reviewer`,
  `reliability-security-builder`, `aws-platform-builder`,
  `multicloud-parity-builder`) must not exist.
* Reviewer hand-offs use `REVIEWER`, `MODEL`, `AGENT_RUN_ID`,
  `CONTEXT_MODE: FRESH`, `INPUT_BUNDLE_SHA256`, `REPOSITORY_HEAD`,
  `VERDICT`.
* FALLBACK_JUSTIFIED is not the policy and not the operating mode.

## Rejected options

* Treating model diversity as the independence control.
* A second Chief of Staff or a second pull request for the same
  milestone layer.
* Letting `platform-product-builder` own `AGENTS.md`.
* Active AWS/GitOps/Azure/GCP builders in Milestone 0.

## Review trigger

A request to add a second coordinator, to require a second model family
before implementation, to activate dormant builders in M0, or to open a
second PR for work that belongs on the existing branch.
