# Roadmap

This commit is a working AWS vertical slice that validates locally. It
is not a landing zone you point at a live organisation without filling
account IDs, CIDRs and identity.

## Now (this repository)

* Principles, ADRs, operating model
* AWS Terraform split into bootstrap, network and workload state
* Transit Gateway routing with static assertions
* EKS with Pod Identity, add-ons, private nodes
* ECR, GitHub OIDC, Secrets Manager contract
* Argo CD bootstrap and Helm golden path
* Sample Go service, probes, NetworkPolicy, SLO rules
* Failure-lab runners for pod, bad rollout, NetworkPolicy, node drain
* Azure and GCP architecture plus Terraform skeletons

## Next

1. Apply the AWS slice to a real network and workload account and run
   `make verify-live`
2. Install kube-prometheus-stack and External Secrets Operator for real
   rather than as a documented bootstrap
3. Azure hub-and-spoke Terraform brought up to the same depth as AWS VPC
4. GCP Shared VPC host/service pair at the same depth

## Later

* Kyverno (or Gatekeeper) policies beyond the documented set
* Binary Authorization / equivalent on GKE and AKS
* Developer portal only if ADR-009's conditions are met
* Hub egress, inspection and hybrid connectivity when there is a real
  requirement
* Cost dashboards fed from native billing exports

## Explicitly not planned

* A universal cloud resource CRD
* A service mesh as a default
* Active-active multi-cloud failover as a platform feature
* Rewriting every legacy application into microservices
