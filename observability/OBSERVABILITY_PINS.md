# Observability pins (Milestone 5)

pstack: observability/m5-offline-contract

These pins were recorded from published checksum files and from SHA-256
hashes of the downloaded archives, extracted binaries, and the committed
ObservabilityContract JSON Schema. They were not invented. Tool
installation may use the network. `make observability-validate` then
validates only from committed files. The gate runs `otelcol-contrib
validate` and `promtool check rules`. It does not start the collector,
does not start Prometheus, and does not open listeners.

## Machine-readable pins

```
otelcol_contrib_version: 0.160.0
otelcol_contrib_git_commit: 982f20b8a8e8a2569fab3e27cf8b008e8a5080c1
otelcol_contrib_releases_git_commit: 5c31bfdc7e8a68aed5e173673c6946299a694ee6
otelcol_contrib_collector_git_commit: cd3455cf3a7f672208140b1ebb1581c542b2b0ed
otelcol_contrib_archive: otelcol-contrib_0.160.0_linux_amd64.tar.gz
otelcol_contrib_archive_url: https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.160.0/otelcol-contrib_0.160.0_linux_amd64.tar.gz
otelcol_contrib_archive_sha256: 7bb60c584c241c86261c2b8697cd3725dd8c56691f5ad5d98454eaa005b47b0c
otelcol_contrib_binary_sha256_linux_amd64: 8524ac54f6e1d4d00d9ba5eea91daadec2ebc31e4da80db9c17eba2e859ecdd4
promtool_version: 3.14.0
promtool_git_commit: d7598b7141418fa35be2b5ec5d0fefb634199610
promtool_archive: prometheus-3.14.0.linux-amd64.tar.gz
promtool_archive_url: https://github.com/prometheus/prometheus/releases/download/v3.14.0/prometheus-3.14.0.linux-amd64.tar.gz
promtool_archive_member: prometheus-3.14.0.linux-amd64/promtool
promtool_archive_sha256: f665c6da19eb7ba399c915d30c7d9793c9b417bf8a749b504bc470678631478d
promtool_binary_sha256_linux_amd64: 9c752bb87eec945b2d7797d20815e2dc54b0d3fed2d2f17df019dbd74560f743
observabilitycontract_schema_path: observability/schemas/observabilitycontract.schema.json
observabilitycontract_schema_sha256: a90b09fe6d2d8bb751497b58d9ec9c8d30bbfd24409ecfaddff13e5b4c4e55a1
actions_checkout_sha: 3d3c42e5aac5ba805825da76410c181273ba90b1
actions_setup_go_sha: b7ad1dad31e06c5925ef5d2fc7ad053ef454303e
actions_setup_terraform_sha: dfe3c3f87815947d99a8997f908cb6525fc44e9e
```

## otelcol-contrib

* Version: `0.160.0` (`otelcol-contrib version 0.160.0`)
* Contrib git commit: `982f20b8a8e8a2569fab3e27cf8b008e8a5080c1` (peeled from annotated tag `v0.160.0` on `open-telemetry/opentelemetry-collector-contrib`)
* Collector git commit: `cd3455cf3a7f672208140b1ebb1581c542b2b0ed` (peeled from annotated tag `v0.160.0` on `open-telemetry/opentelemetry-collector`)
* Release-manifest git commit: `5c31bfdc7e8a68aed5e173673c6946299a694ee6` (peeled from annotated tag `v0.160.0` on `open-telemetry/opentelemetry-collector-releases`)
* Linux amd64 archive SHA-256 (from the release file `otelcol-contrib_0.160.0_linux_amd64.tar.gz.sha256`, verified after download): `7bb60c584c241c86261c2b8697cd3725dd8c56691f5ad5d98454eaa005b47b0c`
* Extracted linux amd64 binary SHA-256 (computed after checksum verification): `8524ac54f6e1d4d00d9ba5eea91daadec2ebc31e4da80db9c17eba2e859ecdd4`

`make observability-validate` installs this exact archive, then runs
`otelcol-contrib validate --config=file:observability/otel/collector-metrics.yaml`.
The `validate` subcommand does not run the collector. The contrib
distribution contains vendor exporters. The committed config must not
reference them.

## promtool (Prometheus)

* Version: `3.14.0` (`promtool, version 3.14.0`, revision `d7598b7141418fa35be2b5ec5d0fefb634199610`)
* Git commit: `d7598b7141418fa35be2b5ec5d0fefb634199610` (peeled from annotated tag `v3.14.0`; matches `promtool --version` revision)
* Linux amd64 archive SHA-256 (from the release `sha256sums.txt`, verified after download): `f665c6da19eb7ba399c915d30c7d9793c9b417bf8a749b504bc470678631478d`
* Extracted linux amd64 `promtool` SHA-256 (computed after checksum verification): `9c752bb87eec945b2d7797d20815e2dc54b0d3fed2d2f17df019dbd74560f743`

`make observability-validate` installs this exact archive member
`prometheus-3.14.0.linux-amd64/promtool`, then runs `promtool check rules`
on `observability/prometheus/rules/sample.yml`. It does not start
Prometheus.

## ObservabilityContract JSON Schema

* Path: `observability/schemas/observabilitycontract.schema.json`
* SHA-256: `a90b09fe6d2d8bb751497b58d9ec9c8d30bbfd24409ecfaddff13e5b4c4e55a1`

`make observability-validate` checks this exact path and SHA-256. Drift
fails the gate. The schema is not a Kubernetes CRD.

## GitHub Actions (unchanged in this milestone)

These SHAs are the pins already present in `.github/workflows/ci.yml`.
Milestone 5 does not add an Action and does not change them. Terraform
CLI/action pins stay in `infra/aws/TERRAFORM_PINS.md`. GitOps tool pins
stay in `gitops/GITOPS_PINS.md`.

* `actions/checkout` v7.0.1: `3d3c42e5aac5ba805825da76410c181273ba90b1`
* `actions/setup-go` v7.0.0: `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e`
* `hashicorp/setup-terraform` v4.0.1: `dfe3c3f87815947d99a8997f908cb6525fc44e9e`

CI Go remains `1.22.12`. `persist-credentials: false` remains. This
workflow does not grant `actions: write`.

## Limitations (evidence)

* Integrity evidence here is published SHA-256 checksums plus locally
  computed SHA-256 of extracted binaries and the committed schema file.
* GPG or SLSA provenance of otelcol-contrib and Prometheus/promtool is
  not recorded, so it is not proved.
* The contrib binary includes cloud and vendor components. Their presence
  in the binary is not permission to use them. The config and semantic
  gate forbid those exporters.
* Tool installation may use the network. Validation after install uses
  only committed local files. No remote schema service is contacted.
* Config and rules parse. No telemetry is emitted, collected, stored,
  queried, or alerted. There is no live scrape.
