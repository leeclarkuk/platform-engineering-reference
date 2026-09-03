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

Three identifiers must not be collapsed:

* **Module tag** `v0.1.0` — the Go module / git tag used with
  `go install github.com/leeclarkuk/frictionctl/cmd/frictionctl@v0.1.0`.
* **Binary version** `0.1.0` — exact stdout of `frictionctl version`
  (no `v` prefix). Do not accept a substring.
* **Go module sums** (`sum`, `gomod_sum`) — checksums of the module zip
  and `go.mod` as returned by `go mod download -json`. They are **not**
  a released executable checksum.

## Decision

Pin files live under `.friction/`. The pin records at least:

* module / repository: `github.com/leeclarkuk/frictionctl`
* install package: `github.com/leeclarkuk/frictionctl/cmd/frictionctl`
* module tag: `v0.1.0`
* commit SHA: `79398cfb55bcc253045bb0065a342a8fe805549a`
* binary version: `0.1.0`
* `sum` and `gomod_sum` (Go module zip and go.mod checksums)
* `checksum_source`: the sumdb lookup URL (documentation only; not proof)
* `journeys_proved: false`

Before install, in an isolated temporary module, with
`GOSUMDB=sum.golang.org`:

```text
go mod download -json github.com/leeclarkuk/frictionctl@v0.1.0
```

The returned `Sum` and `GoModSum` must equal `pin.yml` `sum` and
`gomod_sum` **exactly**. Do not `curl` the sum database as proof. Fail
closed if verification cannot be performed. If the toolchain values
differ from the recorded values, stop, report both, and do not install
or invent replacement hashes.

Only after that match:

```text
go install github.com/leeclarkuk/frictionctl/cmd/frictionctl@v0.1.0
test "$(frictionctl version)" = "0.1.0"
```

Do not use `@latest`. Do not modify the `frictionctl` repository from
this project. Do not run `frictionctl` journeys in Milestone 0.
`frictionctl run` is not a Milestone 0 gate.

## Consequences

* `make friction-pin-verify` is the local and CI proof that the pin is
  installable. It does not prove a golden-path SLO.
* Golden-path journeys wait until a real create-service path exists
  (gap assessment M7).

## Rejected options

* Unpinned `go install ...@latest`.
* Treating `curl https://sum.golang.org/lookup/...` as pin proof.
* Recording a released-binary checksum in place of Go module sums.
* Requiring the executable to print `v0.1.0`.
* Copying archive or frictionctl example journeys and calling them
  proved for this platform.
* Inventing a `frictionctl pin` command here.

## Review trigger

A version bump, a sum mismatch, a journey YAML that claims SLO proof, or
a CI gate that runs `frictionctl` without a matching pin change.
