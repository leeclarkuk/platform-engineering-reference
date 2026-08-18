# Roadmap

This commit is a foundation. It is useful to read, lint, validate and
argue with. It is not a landing zone you point at a live organisation.

## Now (this repository)

* Principles, ADRs, operating model
* AWS Terraform modules for tags, VPC, TGW attachment, EKS, KMS, ECR,
  security baseline, budgets
* Azure and GCP architecture plus Terraform skeletons
* Sample Go service, Helm, Kubernetes base and overlays
* Argo CD bootstrap layout
* `platform` CLI
* CI, policy fixtures, failure-lab write-ups, FinOps models

## Next

1. One AWS network hub and one workload account running the sample
   service under Argo CD
2. External Secrets Operator wired to Secrets Manager in that account
3. Signed images in ECR with a real OIDC GitHub federation example
   (still no standing keys)
4. Azure hub-and-spoke Terraform brought up to the same depth as AWS VPC
5. GCP Shared VPC host/service pair at the same depth

## Later

* Kyverno (or Gatekeeper) policies beyond the documented set
* Binary Authorization / equivalent on GKE and AKS
* Developer portal only if ADR-009's conditions are met
* Failure-lab automation for pod kill and dependency failure
* Cost dashboards fed from native billing exports

## Explicitly not planned

* A universal cloud resource CRD
* A service mesh as a default
* Active-active multi-cloud failover as a platform feature
* Rewriting every legacy application into microservices
