# Prometheus

In-cluster scrape of `/metrics` and the OTel collector. kube-prometheus-stack
is the usual install; this repository does not vendor it.

Recording rules for the sample service live in `rules/sample-service.yaml`.
They measure request rate, error ratio, p95 latency and availability.
Those feed the example SLO. They are demonstration targets, not a company
standard.

Keep cardinality boring: service, method, path, code. User IDs do not
belong on metrics.
