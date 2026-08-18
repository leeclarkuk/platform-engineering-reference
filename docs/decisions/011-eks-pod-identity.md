# ADR-011: EKS Pod Identity for application workloads

- Status: Accepted
- Date: 2026-08-18

## Context

Workloads on EKS need AWS IAM. The established mechanism is IRSA: an OIDC
issuer on the cluster and an annotation on the service account. AWS now
also offers EKS Pod Identity.

## Options considered

1. **EKS Pod Identity for application workloads.** Agent on the nodes.
   IAM role association is an AWS API, not an annotation.
2. **IRSA for everything.** Well understood, works on older clusters,
   requires a cluster OIDC provider and `sts:AssumeRoleWithWebIdentity`.
3. **Node role for pods.** Fast, and every pod can steal the node's
   credentials. Not acceptable.

## Decision

Application workloads and Cluster Autoscaler use EKS Pod Identity. IRSA
remains the escape hatch for add-ons that have not moved, and for AKS/GKE
equivalents which are different products.

GitHub Actions uses a separate OIDC provider on the account. That is not
Pod Identity and not IRSA.

## Rationale

Pod Identity removes the per-cluster OIDC provider and the hop-limit
dance on instance metadata. Associations are visible in the AWS console
and in Terraform. That is easier to audit than an annotation someone
copied between overlays.

IRSA still works. We keep `kubernetes/eks/irsa-patch.yaml` for it. We do
not run both on the sample service.

## Trade-offs

* Pod Identity requires the `eks-pod-identity-agent` add-on and EKS
  versions that support it. 1.31 does.
* Some third-party charts still document only the IRSA annotation.
* AKS and GKE do not have this API. The Kubernetes overlay boundary stays.

## Consequences

* IMDS hop limit on nodes is 1. Pods should not need the node metadata
  service.
* Terraform owns `aws_eks_pod_identity_association`. Git does not store
  the role ARN on the golden-path service account unless someone opts
  into IRSA.

## When we would reconsider

* A required add-on that only supports IRSA and cannot run as Pod
  Identity.
* A cluster version that cannot run the Pod Identity agent.
