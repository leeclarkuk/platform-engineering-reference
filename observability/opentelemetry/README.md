# OpenTelemetry

Application contract: OTLP. Set `OTEL_EXPORTER_OTLP_ENDPOINT` when a
collector is in the cluster. The sample service records Prometheus
metrics now and treats OTLP as configuration. Wiring the full SDK is
the next increment so unit tests do not download half the tracing
ecosystem to assert `/health`.

Collector sits in the cluster, receives OTLP, exports metrics to
Prometheus and traces to a backend you actually staff (Tempo,
Grafana Cloud, vendor, or native X-Ray/Azure Monitor/Cloud Trace via
their OTLP intakes).
