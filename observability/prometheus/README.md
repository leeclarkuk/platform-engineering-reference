# Prometheus

In-cluster scrape of `/metrics` and the OTel collector. kube-prometheus-stack
is the usual install; this repository does not vendor it. Keep cardinality
boring: service, method, path, code. User IDs do not belong on metrics.
