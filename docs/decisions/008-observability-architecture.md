# ADR-008: Observability architecture

- Status: Accepted
- Date: 2026-08-18

## Context

Each cloud has a native observability stack. Application teams still need
one way to instrument. SREs need SLOs that are not screenshots of CloudWatch.

## Options considered

1. **OpenTelemetry SDK in apps, Prometheus/Grafana in cluster, native
   backends for platform logs.** OTLP as the contract.
2. **Cloud-native only.** CloudWatch, Azure Monitor, Cloud Monitoring.
   Lowest extra infrastructure, three query languages, weak cross-cloud.
3. **Vendor APM as the standard.** Fast if funded, lock-in, still need
   native logs for the control plane.
4. **Elastic / Loki / Tempo self-hosted everything.** Powerful, easy to
   under-staff.

## Decision

OpenTelemetry is the application contract for traces and metrics. Prometheus
scrapes in-cluster metrics. Grafana is the common dashboard layer where we
run one. Native logging (CloudWatch, Log Analytics, Cloud Logging) remains
the system of record for platform and audit logs.

The example SLO on the sample service is 99.9% availability and 95% of
requests under 300ms. Those numbers are examples. They are not a company
standard. A public API and a nightly batch job should not share them.

## Rationale

Instrumentation is the part application teams can do once. Query backends
are allowed to differ. Forcing every log through a self-hosted pile on day
one recreates the multi-cloud problem inside observability.

A vendor APM can sit on the OTLP contract later. That is a buying decision,
not an instrumentation decision. If you instrument to a vendor SDK first,
you will pay to re-instrument.

## Trade-offs

* Two places to look during an incident if native logs and Grafana both
  exist. Runbooks must say which is authoritative for which question.
* OTel has foot-guns (sampler config, context propagation, cardinality).
  The golden path sets conservative defaults.
* High-cardinality metrics will cost real money. Metric design is a review
  item, not an afterthought.

## Consequences

* Sample service exposes `/metrics` and emits traces via OTLP when
  configured.
* Alerts page on SLIs, not on CPU averages.
* Error budgets are owned by the application team. The platform team owns
  the platform SLOs (API server, Argo CD, ingress).

## When we would reconsider

* A single-cloud estate where native observability is good enough and the
  extra stack is unjustified.
* A funded observability platform (Grafana Cloud, Honeycomb, Datadog) that
  speaks OTLP and takes over operations.
