locals {
  # Pod Identity is declared for later workloads, but Milestone 2 creates no
  # worker nodes and no pods. The association is therefore non-operational
  # until compatible compute exists.
  pod_identity_non_operational_until_compute = true

  # Pod Identity role trust contract (Milestone 2):
  # * Principal.Service = pods.eks.amazonaws.com
  # * Actions = sts:AssumeRole and sts:TagSession
  pod_identity_trust_principal_service = "pods.eks.amazonaws.com"
  pod_identity_trust_actions           = ["sts:AssumeRole", "sts:TagSession"]

  pod_identity_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = local.pod_identity_trust_principal_service
        }
        Action = local.pod_identity_trust_actions
      }
    ]
  })

  pod_identity_trust_policy_decoded = jsondecode(local.pod_identity_trust_policy)

  pod_identity_trust_principal_service_rendered = try(
    local.pod_identity_trust_policy_decoded.Statement[0].Principal.Service,
    ""
  )

  pod_identity_trust_actions_rendered = try(
    local.pod_identity_trust_policy_decoded.Statement[0].Action,
    []
  )

  pod_identity_trust_actions_rendered_list = try(
    tolist(local.pod_identity_trust_actions_rendered),
    [local.pod_identity_trust_actions_rendered]
  )

  pod_identity_trust_semantic_ok = (
    local.pod_identity_trust_principal_service_rendered == local.pod_identity_trust_principal_service &&
    sort(local.pod_identity_trust_actions_rendered_list) == sort(local.pod_identity_trust_actions)
  )
}

resource "aws_iam_role" "eks_cluster_role" {
  name = var.eks_cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_security_group" "eks_cluster" {
  name        = "m2-eks-cluster-sg"
  description = "EKS control plane security group (Milestone 2 validation only)."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.eks_cluster.id]

    endpoint_public_access  = true
    endpoint_private_access = false
  }

  # Milestone 2 is not modelling workloads or node pools.
  enabled_cluster_log_types = []
}

resource "aws_eks_addon" "pod_identity_agent" {
  depends_on = [aws_eks_cluster.this]

  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_iam_role" "pod_identity_role" {
  name = var.pod_identity_role_name

  # Pod Identity role trust contract (see locals above).
  assume_role_policy = local.pod_identity_trust_policy

  lifecycle {
    precondition {
      condition     = local.pod_identity_trust_semantic_ok
      error_message = "Pod Identity trust policy must trust pods.eks.amazonaws.com and allow sts:AssumeRole and sts:TagSession."
    }
  }
}

resource "aws_eks_pod_identity_association" "this" {
  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role.pod_identity_role,
  ]

  cluster_name = aws_eks_cluster.this.name

  # Milestone 1 contract strings (apps/sample) are used as Terraform inputs.
  namespace       = var.service_account_namespace
  service_account = var.service_account_name

  role_arn = aws_iam_role.pod_identity_role.arn
}

