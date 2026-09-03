locals {
  # Pod Identity is declared for later workloads, but Milestone 2 creates no
  # worker nodes and no pods. The association is therefore non-operational
  # until compatible compute exists.
  pod_identity_non_operational_until_compute = true
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

  # Source literals: Principal.Service pods.eks.amazonaws.com and Action
  # [sts:AssumeRole, sts:TagSession] in pod-identity-trust-policy.json.
  # Semantic enforcement is scripts/check-pod-identity-trust.sh in
  # make terraform-validate. terraform validate does not evaluate lifecycle
  # preconditions, so none are used here.
  assume_role_policy = file("${path.module}/pod-identity-trust-policy.json")
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

