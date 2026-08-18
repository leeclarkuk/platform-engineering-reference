terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

variable "name" {
  description = "Cluster name."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the control plane and nodes."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key for secrets encryption."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS version."
  type        = string
  default     = "1.31"
}

variable "desired_size" {
  description = "Desired node count."
  type        = number
  default     = 2
}

variable "instance_types" {
  description = "Node instance types."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-eks-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_security_group" "cluster" {
  name        = "${var.name}-eks-cluster"
  description = "EKS control plane additional SG"
  vpc_id      = data.aws_subnet.first.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-eks-cluster" })
}

data "aws_subnet" "first" {
  id = var.subnet_ids[0]
}

resource "aws_vpc_security_group_ingress_rule" "cluster_nodes" {
  security_group_id            = aws_security_group.cluster.id
  description                  = "Nodes to control plane"
  referenced_security_group_id = aws_security_group.node.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "cluster" {
  security_group_id = aws_security_group.cluster.id
  description       = "Control plane egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "node" {
  name        = "${var.name}-eks-node"
  description = "EKS nodes"
  vpc_id      = data.aws_subnet.first.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-eks-node" })
}

resource "aws_vpc_security_group_ingress_rule" "node_self" {
  security_group_id            = aws_security_group.node.id
  description                  = "Node to node"
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "node_cluster" {
  security_group_id            = aws_security_group.node.id
  description                  = "Control plane to nodes"
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "node" {
  security_group_id = aws_security_group.node.id
  description       = "Node egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version
  tags     = var.tags

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.name}-node-"
  tags        = var.tags

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.instance_types
  tags            = var.tags

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.desired_size + 2
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Private API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "node_role_arn" {
  description = "Node IAM role ARN."
  value       = aws_iam_role.node.arn
}

output "oidc_issuer" {
  description = "OIDC issuer URL for IRSA."
  value       = try(aws_eks_cluster.this.identity[0].oidc[0].issuer, null)
}
