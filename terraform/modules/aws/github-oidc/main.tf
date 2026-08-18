terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

variable "github_org" {
  description = "GitHub organisation or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository name without the org prefix."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for IAM role names."
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repositories the publish role may push to."
  type        = list(string)
}

variable "state_bucket_arn" {
  description = "Terraform state bucket ARN. Empty skips state permissions (local backends)."
  type        = string
  default     = ""
}

variable "state_lock_table_arn" {
  description = "Optional DynamoDB lock table ARN for older backends."
  type        = string
  default     = ""
}

variable "plan_environments" {
  description = "GitHub environments allowed to assume the plan role, plus pull requests."
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "deploy_environments" {
  description = "GitHub environments allowed to assume the deploy role. Do not include pull_request."
  type        = list(string)
  default     = ["dev"]
}

variable "publish_ref" {
  description = "Git ref that may push images. Typically refs/heads/main."
  type        = string
  default     = "refs/heads/main"
}

variable "thumbprints" {
  description = "GitHub Actions OIDC provider thumbprints. Override if GitHub rotates the CA."
  type        = list(string)
  default = [
    "d89e3bd43d5d909b47a969777e3ca4ecd3d6c9fe",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider in this account. Set false if it already exists."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when create_oidc_provider is false."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  repo          = "${var.github_org}/${var.github_repo}"
  oidc_provider = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
  oidc_host     = "token.actions.githubusercontent.com"
  account_id    = data.aws_caller_identity.current.account_id
  plan_subs = concat(
    [for env in var.plan_environments : "repo:${local.repo}:environment:${env}"],
    ["repo:${local.repo}:pull_request"]
  )
  deploy_subs = concat(
    [for env in var.deploy_environments : "repo:${local.repo}:environment:${env}"],
    ["repo:${local.repo}:ref:${var.publish_ref}"]
  )
  publish_subs = [
    "repo:${local.repo}:ref:${var.publish_ref}",
    "repo:${local.repo}:environment:dev",
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://${local.oidc_host}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.thumbprints
  tags            = merge(var.tags, { Name = "${var.name_prefix}-github" })
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = local.plan_subs
    }
  }
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = local.deploy_subs
    }
  }
}

data "aws_iam_policy_document" "publish_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = local.publish_subs
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.name_prefix}-github-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
  tags               = merge(var.tags, { Purpose = "github-plan" })
}

resource "aws_iam_role" "deploy" {
  name               = "${var.name_prefix}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
  tags               = merge(var.tags, { Purpose = "github-deploy" })
}

resource "aws_iam_role" "publish" {
  name               = "${var.name_prefix}-github-image-publish"
  assume_role_policy = data.aws_iam_policy_document.publish_trust.json
  tags               = merge(var.tags, { Purpose = "github-image-publish" })
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid = "ReadInfra"
    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "ecr:Describe*",
      "ecr:GetAuthorizationToken",
      "ecr:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "logs:Describe*",
      "logs:List*",
      "ram:Get*",
      "ram:List*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.state_bucket_arn == "" ? [] : [var.state_bucket_arn]
    content {
      sid = "StateRead"
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
      ]
      resources = [
        statement.value,
        "${statement.value}/*",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.state_lock_table_arn == "" ? [] : [var.state_lock_table_arn]
    content {
      sid       = "LegacyLockRead"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
      resources = [statement.value]
    }
  }
}

data "aws_iam_policy_document" "deploy" {
  # Terraform apply for this composition needs EC2/EKS/KMS/Secrets Manager
  # create and delete. The control is the OIDC trust, not Resource ARNs on
  # every Describe call. This is not an administrator identity.
  # checkov:skip=CKV_AWS_107: trust is repo and environment scoped; apply must read secret metadata
  # checkov:skip=CKV_AWS_108: trust is repo and environment scoped; apply must manage the example secret container
  statement {
    sid = "TerraformWorkload"
    actions = [
      "ec2:*",
      "eks:*",
      "ecr:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "logs:*",
      "kms:*",
      "secretsmanager:*",
      "ram:AcceptResourceShareInvitation",
      "ram:GetResourceShareInvitations",
      "ram:GetResourceShares",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamScopedToPrefix"
    actions = [
      "iam:PassRole",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:role/${var.name_prefix}-*",
      "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_host}",
    ]
  }

  dynamic "statement" {
    for_each = var.state_bucket_arn == "" ? [] : [var.state_bucket_arn]
    content {
      sid = "StateWrite"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      resources = [
        statement.value,
        "${statement.value}/*",
      ]
    }
  }
}

data "aws_iam_policy_document" "publish" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

resource "aws_iam_role_policy" "deploy" {
  # Terraform apply for this composition needs EC2/EKS/logs create and delete.
  # IAM mutations stay name-prefixed in the sibling statement. This is not an admin role.
  # checkov:skip=CKV_AWS_355: scoped by role trust to GitHub environments, not by Resource ARNs on every EC2 action
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy" "publish" {
  name   = "publish"
  role   = aws_iam_role.publish.id
  policy = data.aws_iam_policy_document.publish.json
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN."
  value       = local.oidc_provider
}

output "plan_role_arn" {
  description = "IAM role ARN for terraform plan."
  value       = aws_iam_role.plan.arn
}

output "deploy_role_arn" {
  description = "IAM role ARN for terraform apply from GitHub environments."
  value       = aws_iam_role.deploy.arn
}

output "publish_role_arn" {
  description = "IAM role ARN for pushing images to ECR."
  value       = aws_iam_role.publish.arn
}

output "trust_subjects" {
  description = "OIDC subjects allowed to assume each role."
  value = {
    plan    = local.plan_subs
    deploy  = local.deploy_subs
    publish = local.publish_subs
  }
}
