# Cost models

Figures below are **order-of-magnitude models** for a small platform
footprint in one region. They are not quotes. Replace unit prices with
your contract rates.

Assumptions: one non-prod + one prod-like cluster, moderate logs, no
multi-cloud data sync.

## AWS (monthly, illustrative)

| Driver | Why it moves | Model range |
| --- | --- | --- |
| EKS control plane | Fixed per cluster | Low hundreds of USD |
| Nodes | Size and count | Usually the largest compute line |
| NAT Gateway | Hours + GB processed | Often surprises people |
| Load balancers | Per hour + LCU | Ingress shape |
| CloudWatch logs | Ingestion GB | Verbose apps dominate |
| Data transfer | AZ, region, internet, TGW | Cross-AZ chatty services |
| GuardDuty / Security Hub | Findings volume | Security baseline, keep it |

Optimisation: centralise NAT, VPC endpoints for S3/ECR, right-size
nodes, sample logs, prefer same-AZ, turn off idle non-prod at night
only if start-up is tested.

## Azure

| Driver | Notes |
| --- | --- |
| AKS | Control plane SKU + node pools |
| Azure Firewall / NVA | Easy to exceed VM spend |
| Bandwidth | Egress is the trap |
| Log Analytics | Ingestion and retention |
| Private Endpoints | Per-endpoint cost, still usually cheaper than public data leaks |

Virtual WAN is a product cost. Do not enable it to make a diagram tidy.

## GCP

| Driver | Notes |
| --- | --- |
| GKE | Autopilot vs Standard changes the bill shape |
| Cloud NAT | Same surprise as AWS NAT |
| Logging | Exclusion filters are a design choice |
| Egress | Inter-region is easy because VPCs are global |

## Kubernetes

Idle requested-but-unused CPU is a FinOps bug. HPA without requests is
an SRE bug. You need both.

## What we will not do

Publish a "typical production price". There isn't one. The
`finops/cost-models/estimate.example.yaml` file is the template for a
real estimate.
