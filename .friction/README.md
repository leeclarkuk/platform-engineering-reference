# frictionctl

Pin: [pin.yml](pin.yml). Format: [ADR-0006](../docs/adr/0006-frictionctl-pin-format.md).

`frictionctl` module tag `v0.1.0` is recorded so later milestones can
install a known CLI. The executable prints `0.1.0` (no `v` prefix).
`sum` and `gomod_sum` are Go module zip and `go.mod` checksums, not a
released-binary checksum.

Proof of the pin is `make friction-pin-verify`: an isolated
`go mod download -json` whose `Sum` / `GoModSum` must match this file
exactly, then `go install ...@v0.1.0`, then
`test "$(frictionctl version)" = "0.1.0"`. Curling the sum database is
not proof. Fail closed if the toolchain cannot verify.

There are **no** journeys or budgets in this repository yet.
`journeys_proved` is false. Do not run `frictionctl` as a merge gate until
a golden path exists and a baseline is captured. Do not run journeys in
Milestone 0.

Do not modify the `frictionctl` repository from this project.
