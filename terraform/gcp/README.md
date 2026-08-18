# GCP Terraform skeleton

A Shared VPC-shaped network in one project so `terraform validate` works
without an organisation. Real estates split host and service projects.
See `landing-zones/gcp` and `docs/architecture/gcp.md`.

GKE is omitted until Workload Identity, Artifact Registry and the host
project IAM (`compute.networkUser`) are designed. A cluster without those
is a demo, not a platform.
