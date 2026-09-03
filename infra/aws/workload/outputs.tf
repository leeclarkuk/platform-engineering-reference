output "eks_cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "EKS cluster name created by the workload root."
}

output "pod_identity_association_namespace" {
  value       = var.service_account_namespace
  description = "Pod Identity association namespace (Terraform input string)."
}

output "pod_identity_association_service_account" {
  value       = var.service_account_name
  description = "Pod Identity association service account (Terraform input string)."
}

output "pod_identity_role_arn" {
  value       = aws_iam_role.pod_identity_role.arn
  description = "IAM role ARN referenced by aws_eks_pod_identity_association."
}

