variable "cluster_addons" {
  description = "EKS add-ons to manage. Versions are resolved by EKS when omitted so this tree stays valid across patch releases. Pin in production tfvars."
  type = map(object({
    version                  = optional(string)
    configuration_values     = optional(string)
    resolve_conflicts_update = optional(string, "OVERWRITE")
  }))
  default = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
    metrics-server         = {}
  }
}

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  configuration_values        = each.value.configuration_values
  resolve_conflicts_on_update = each.value.resolve_conflicts_update
  tags                        = var.tags

  depends_on = [aws_eks_node_group.this]
}

variable "enable_cluster_autoscaler_irsa" {
  description = "Create an IAM role for Cluster Autoscaler. The controller itself is installed by GitOps, not Terraform. Uses Pod Identity."
  type        = bool
  default     = true
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler_irsa ? 1 : 0
  statement {
    sid = "AutoscalerDescribe"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }
  statement {
    sid = "AutoscalerMutate"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  count              = var.enable_cluster_autoscaler_irsa ? 1 : 0
  name               = "${var.name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count  = var.enable_cluster_autoscaler_irsa ? 1 : 0
  name   = "autoscaler"
  role   = aws_iam_role.cluster_autoscaler[0].id
  policy = data.aws_iam_policy_document.cluster_autoscaler[0].json
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  count           = var.enable_cluster_autoscaler_irsa ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler[0].arn
  tags            = var.tags
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler, if created."
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}
