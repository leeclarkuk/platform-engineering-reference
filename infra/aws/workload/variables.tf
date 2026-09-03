variable "vpc_id" {
  type        = string
  description = "VPC ID from the network root."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs from the network root."
}

variable "cluster_name" {
  type        = string
  default     = "m2-eks-cluster"
  description = "EKS cluster name for the workload root."
}

variable "service_account_namespace" {
  type        = string
  default     = "apps"
  description = <<EOT
Terraform input string for the service account namespace.

Provenance: `testdata/workloadcontract-valid.yaml` (Milestone 1 contract fixture),
where `spec.serviceAccount.namespace` is `apps`.

Milestone 2 must not parse `testdata/` at runtime. This value is copied as a
Terraform default.
EOT
}

variable "service_account_name" {
  type        = string
  default     = "sample"
  description = <<EOT
Terraform input string for the service account name.

Provenance: `testdata/workloadcontract-valid.yaml` (Milestone 1 contract fixture),
where `spec.serviceAccount.name` is `sample`.

Milestone 2 must not parse `testdata/` at runtime. This value is copied as a
Terraform default.
EOT
}

variable "eks_cluster_role_name" {
  type        = string
  default     = "m2-eks-cluster-role"
  description = "IAM role name for the EKS control plane."
}

variable "pod_identity_role_name" {
  type        = string
  default     = "m2-pod-identity-role"
  description = "IAM role name for the Pod Identity association."
}

