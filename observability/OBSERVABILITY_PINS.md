# Observability pins (Milestone 5)

These pins were recorded from published checksum files and from SHA-256
hashes of the downloaded archives, extracted binaries, and the committed
ObservabilityContract JSON Schema. They were not invented. Tool
installation may use the network. `make observability-validate` then
validates only from committed files. The gate runs `otelcol-contrib
validate` and `promtool check rules`. It does not start the collector,
does not start Prometheus, and does not open listeners.

GitHub Action `uses:` pins live in `.github/workflows/ci.yml`. Terraform
CLI/action pins stay in `infra/aws/TERRAFORM_PINS.md`. GitOps tool pins
stay in `gitops/GITOPS_PINS.md`.

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
```

## otelcol-contrib

* Version: `0.160.0` (`otelcol-contrib version 0.160.0`)
* Contrib source: annotated tag `v0.160.0` on `open-telemetry/opentelemetry-collector-contrib`
* Collector source: annotated tag `v0.160.0` on `open-telemetry/opentelemetry-collector`
* Release-manifest source: annotated tag `v0.160.0` on `open-telemetry/opentelemetry-collector-releases`
* Linux amd64 archive checksum: from the release file `otelcol-contrib_0.160.0_linux_amd64.tar.gz.sha256`, verified after download
* Extracted linux amd64 binary checksum: computed after checksum verification

`make observability-validate` installs this exact archive, then runs
`otelcol-contrib validate --config=file:observability/otel/collector-metrics.yaml`.
The `validate` subcommand does not run the collector. The contrib
distribution contains vendor exporters. The committed config must not
reference them.

## promtool (Prometheus)

* Version: `3.14.0` (`promtool, version 3.14.0`)
* Source: annotated tag `v3.14.0` (matches `promtool --version` revision)
* Linux amd64 archive checksum: from the release `sha256sums.txt`, verified after download
* Extracted linux amd64 `promtool` checksum: computed after checksum verification

`make observability-validate` installs this exact archive member
`prometheus-3.14.0.linux-amd64/promtool`, then runs `promtool check rules`
on `observability/prometheus/rules/sample.yml`. It does not start
Prometheus.

## ObservabilityContract JSON Schema

* Path: `observability/schemas/observabilitycontract.schema.json`

`make observability-validate` checks this exact path and SHA-256. Drift
fails the gate. The schema is not a Kubernetes CRD.

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
