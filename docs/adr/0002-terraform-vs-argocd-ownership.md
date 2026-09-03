# ADR-0002: Terraform versus Argo CD ownership, including Pod Identity versus ServiceAccount

- Status: Accepted
- Date: 2026-09-03

## Context

Two control planes will exist later: Terraform for AWS foundations and
Argo CD for cluster desired state. Archive history showed leaky ownership:
Terraform created EKS add-ons and Pod Identity associations while GitOps
created ServiceAccounts and a ClusterSecretStore, and a Helm chart plus a
Kustomize base both described `sample-service`.

## Decision

Terraform owns cloud-API objects only: accounts and state backends, VPC and
Transit Gateway, EKS control plane and **EKS add-ons** (`aws_eks_addon`),
IAM roles, OIDC providers, KMS, Secrets Manager, ECR, Pod Identity
**associations**.

Argo CD owns Kubernetes API objects only: Applications, Helm releases,
namespaces, workloads, in-cluster controllers, ClusterSecretStore,
ServiceAccounts.

The ServiceAccount name (`namespace` + `name`) is a **contract string**.
Terraform’s `aws_eks_pod_identity_association` refers to that string.
GitOps creates the ServiceAccount. Terraform does not create Kubernetes
ServiceAccounts, Deployments, or Helm releases. GitOps does not create IAM
roles, OIDC providers, or EKS add-ons.

## Consequences

* No object has two owners.
* Cluster Autoscaler IAM stays in Terraform; the controller install stays
  in GitOps.
* Milestone 0 contains neither Terraform nor GitOps trees; this ADR binds
  later milestones.

## Rejected options

* Terraform `kubernetes_*` / `helm_release` for application or add-on
  workloads.
* GitOps-managed IAM or OIDC.
* CI `kubectl`/`helm` as the promotion path.

## Review trigger

Any later PR that adds Terraform Kubernetes providers, Helm releases in
Terraform, or IAM manifests in `gitops/`.
