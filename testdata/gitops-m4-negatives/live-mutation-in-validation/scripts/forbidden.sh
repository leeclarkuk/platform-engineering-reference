#!/bin/sh
# Fixture only. Must fail check-no-cloud-mutation.sh.
kubectl apply -f /dev/null
helm install sample ./chart
terraform apply
argocd app sync sample
aws s3 rm s3://example-bucket/prefix --recursive
