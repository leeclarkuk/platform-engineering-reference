#!/bin/sh
# Fixture only. Must fail cloud-mutation and live-start scanners.
kubectl apply -f /dev/null
helm install sample ./chart
terraform apply
argocd app sync sample
aws s3 ls
otelcol-contrib --config=observability/otel/collector-metrics.yaml
prometheus --config.file=/tmp/prometheus.yml
