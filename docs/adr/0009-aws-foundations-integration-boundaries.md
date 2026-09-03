# ADR-0009: AWS foundations (Milestone 2) roots, contracts, and Pod Identity status

- Status: Accepted
- Date: 2026-09-03

## Context

Milestone 2 adds AWS foundations Terraform that is locally verifiable, without
AWS credentials, and without any Kubernetes or Helm objects.

The repository rule for Milestone 2 is simple: bootstrap, network, and
workload are three independent Terraform roots, each with its own locked
provider set. Pod Identity is declared, but the milestone intentionally
creates no worker nodes and no pods, so the identity path is non-operational
until compatible compute exists.

## Decision

Milestone 2 uses exactly three Terraform roots under `infra/aws/`:

### Root 1: `infra/aws/bootstrap`

Purpose:
* State bootstrap prerequisites only.

Creates:
* `aws_s3_bucket` for eventual Terraform remote state
* `aws_dynamodb_table` for eventual state locking

Inputs:
* `state_bucket_name` (no default, so this repo never commits a live bucket name)
* `state_lock_table_name`

Outputs:
* `state_bucket_name`
* `state_lock_table_name`

Chicken-and-egg:
* Remote-state backends are validated in this milestone with
  `terraform init -backend=false`.
* The bucket and lock table exist for later Milestones, but this milestone does
  not attempt to create them and then re-run with a live backend.

### Root 2: `infra/aws/network`

Purpose:
* VPC and subnets only, no Transit Gateway.

Creates:
* `aws_vpc`
* an internet gateway
* public subnets and route table associations

Outputs:
* `vpc_id`
* `public_subnet_ids`

Rejected:
* Transit Gateway (TGW)
* anything beyond VPC and subnets

### Root 3: `infra/aws/workload`

Purpose:
* Workload-side EKS control plane plus Pod Identity inputs.

Creates:
* `aws_eks_cluster`
* supporting AWS IAM resources for the EKS control plane
* `aws_eks_addon` for `eks-pod-identity-agent`
* `aws_eks_pod_identity_association`

Inputs:
* `vpc_id`
* `subnet_ids`
* `service_account_namespace` and `service_account_name`

ServiceAccount strings provenance:
* Defaults are copied from the Milestone 1 WorkloadContract fixture:
  `testdata/workloadcontract-valid.yaml`.
* `spec.serviceAccount.namespace` is `apps`
* `spec.serviceAccount.name` is `sample`
* Milestone 2 does not read `testdata/` at runtime, it only uses fixed strings.

Pod Identity non-operational status:
* There are no worker nodes and no pods in Milestone 2.
* `aws_eks_pod_identity_association` is declared, and the role trust principal
  is `pods.eks.amazonaws.com`, but it is not a working identity path until
  compatible compute is added in a later milestone.

Rejected:
* Worker nodes, node pools, Fargate, or any pod-creating resources
* Kubernetes objects and any Kubernetes or Helm Terraform ownership

## Rejected options

* Single-module Terraform or shared Terraform state between the three roots.
* TGW-based networking.
* Node groups in Milestone 2.
* Kubernetes provider, Helm provider, `helm_release`, or any `kubernetes_*`
  resources/data sources under `infra/aws/`.
* Kubernetes ServiceAccount creation, lookup, or `testdata/` parsing by Terraform.

## Consequences

* `make terraform-validate` runs `terraform fmt -check -recursive`, the
  lexical boundary scan, the CI-executed Pod Identity trust JSON check
  (`scripts/check-pod-identity-trust.sh`), then `terraform init -backend=false`
  and `terraform validate` for all three roots with AWS credentials unset.
* `terraform validate` does not evaluate lifecycle preconditions. The trust
  contract is enforced by the static JSON check against independent constants,
  not by a Terraform-time assertion.
* Pod Identity is intentionally non-operational in this milestone.
* A dedicated boundary scan rejects Kubernetes/Helm constructs and any
  terraform apply/destroy or Helm install/upgrade ownership text under
  `infra/aws/`. That scan is lexical only.

