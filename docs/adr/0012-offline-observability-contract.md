# ADR-0012: Offline observability contract for workload sample

- Status: Accepted
- Date: 2026-09-05

## Context

Milestone 4 closed with Application `sample` consuming the existing Helm
chart under `templates/`. There is still no live cluster, no scrape
target, and no monitoring stack. The next authorised slice is a
versioned observability contract that can be linted offline.

Lee approved `M5_IMPLEMENTATION_APPROVAL` for a standalone
ObservabilityContract under `observability/`. The WorkloadContract
schema and CLI stay frozen (ADR-0008). AppProject `platform` stays
Deployment, Service, and ServiceAccount only (ADR-0011). Terraform still
must not grow `kubernetes_*` or `helm_release` objects (ADR-0002,
ADR-0009).

`templates/` exposes port `8080` named `http`. There is no `/metrics`
path. A scrape claim would be fiction.

## Decision

Accepted because Lee approved this specification.

* Kind is `ObservabilityContract`. `apiVersion` is
  `platform.engineering.reference/v1alpha1`. The schema lives at
  `observability/schemas/observabilitycontract.schema.json` with
  `additionalProperties: false`. It is not a Kubernetes CRD and it is
  not under `api/`.
* One instance: `observability/contracts/sample.yaml`. Identity strings
  are copied from the valid WorkloadContract fixture, Helm Chart/values,
  and Application `sample`: name `sample`, namespace `apps`, owner
  `platform`, `service.version` `0.1.0`. `prometheus.job` is `sample`.
  `deployment.environment.name` is the design-only const `local-design`.
* Collector config is a non-Kubernetes file at
  `observability/otel/collector-metrics.yaml`. Metrics pipeline only:
  OTLP receiver, `memory_limiter`, `resource`, `batch`, Prometheus
  exporter, debug exporter. No logs, traces, Kubernetes discovery,
  remote write, or cloud/vendor exporters.
* Alerting is a standard Prometheus rule file at
  `observability/prometheus/rules/sample.yml`, not
  `monitoring.coreos.com/v1` PrometheusRule. Recording and target-health
  rules use only `up{job="sample"}`. Max severity is `warning`. Owner
  label is `platform`. No paging.
* `make observability-validate` proves schema, field semantics,
  cross-artifact identity, pinned `otelcol-contrib validate` (no
  collector start, no listeners), pinned `promtool check rules`, pin
  checksums, and named negative fixtures. Tool install may use the
  network. Validation does not.
* Pins are recorded in `observability/OBSERVABILITY_PINS.md` from
  published checksums and computed SHA-256. Existing Go, Terraform,
  GitOps, and Action pins are unchanged. No new GitHub Action.
  `persist-credentials: false` stays. The workflow does not gain
  `actions: write`.
* Claim `OBS-M5-000` is locally validated design only. Config and rules
  parse. No telemetry is emitted, collected, stored, queried, or
  alerted.

## Consequences

* Milestone 5 does not prove a monitoring stack, a scrape, a dashboard,
  or an on-call path.
* The contrib collector binary contains vendor exporters. Their presence
  in the binary is not permission to use them. The config and semantic
  gate forbid those exporters.
* AWS and GitOps builders stay dormant. They must not absorb this
  contract.
* Milestone 6 is not started.

## Rejected options

* Extending WorkloadContract with observability fields (reopens
  ADR-0008, mutates the closed Milestone 1 schema and CLI).
* Kubernetes monitoring CRDs (ServiceMonitor, PodMonitor, PrometheusRule,
  GrafanaDashboard) under `observability/` or `gitops/`.
* Terraform ownership of the collector (`kubernetes_*`, `helm_release`,
  IAM).
* A new Argo Application, AppProject whitelist broadening, or auto-sync.
* Duplicating the sample workload under `gitops/apps/`.
* Speculative SLOs, latency, error-rate, or availability objectives.
* Paging or `critical` severity.
* Live scrape, remote write, cloud/vendor exporters, logs/traces
  pipelines, secrets, or AWS endpoints as proof.
* Starting the collector or Prometheus in the gate.

## Review trigger

A PR that extends WorkloadContract, adds monitoring CRDs, starts a
collector in CI, claims a live scrape, adds paging, invents SLOs, or
opens a second pull request for this layer.
