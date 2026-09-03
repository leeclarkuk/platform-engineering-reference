# ADR-0006: frictionctl pin format

- Status: Accepted
- Date: 2026-09-03

## Context

Developer experience is a platform property. `frictionctl`
(https://github.com/leeclarkuk/frictionctl) measures golden-path friction
and can fail CI on regression. The CLI has `run`, `compare`, `list`,
`explain` and `version`. It has **no** `pin` subcommand. This repository
must record the pin itself.

Tag `v0.1.0` was verified on GitHub: annotated tag object
`3e3ec8cbd84af46eb38a48a53f76b8646788e0cd` points at commit
`79398cfb55bcc253045bb0065a342a8fe805549a`.

## Decision

Pin files live under `.friction/`. The pin records at least:

* module / repository: `github.com/leeclarkuk/frictionctl`
* install package: `github.com/leeclarkuk/frictionctl/cmd/frictionctl`
* semver: `v0.1.0`
* commit SHA: `79398cfb55bcc253045bb0065a342a8fe805549a`

Do not use `@latest`. Do not modify the `frictionctl` repository from this
project. Milestone 0 records the pin and states **journeys are not
proved**. `frictionctl run` is not a Milestone 0 gate.

## Consequences

* Install, when needed later: `go install github.com/leeclarkuk/frictionctl/cmd/frictionctl@v0.1.0`
  and confirm `frictionctl version` plus the commit when building from source.
* Golden-path journeys wait until a real create-service path exists
  (gap assessment M7).

## Rejected options

* Unpinned `go install ...@latest`.
* Copying archive or frictionctl example journeys and calling them proved
  for this platform.
* Inventing a `frictionctl pin` command here.

## Review trigger

A version bump, a journey YAML that claims SLO proof, or a CI gate that
runs `frictionctl` without a matching pin change.
