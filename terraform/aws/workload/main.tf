terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region              = var.region
  allowed_account_ids = compact([var.workload_account_id])

  default_tags {
    tags = module.tags.tags
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "dev, staging or prod."
  type        = string
}

variable "owner" {
  description = "Owning team."
  type        = string
  default     = "platform"
}

variable "cost_centre" {
  description = "Cost centre."
  type        = string
  default     = "platform-engineering"
}

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "management_account_id" {
  description = "Organisation management account ID. Informational."
  type        = string
}

variable "network_account_id" {
  description = "Network hub account ID."
  type        = string
}

variable "workload_account_id" {
  description = "Workload account ID this stack must run in."
  type        = string
}

variable "vpc_cidr" {
  description = "Workload VPC CIDR."
  type        = string
}

variable "network_hub_cidr" {
  description = "Hub VPC CIDR. Routed to the Transit Gateway from private subnets."
  type        = string
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID from the network stack."
  type        = string
}

variable "transit_gateway_hub_route_table_id" {
  description = "Hub TGW route table. Used to add a static route to this VPC when manage_tgw_routes is true."
  type        = string
  default     = null
}

variable "transit_gateway_spoke_route_table_id" {
  description = "Spoke TGW route table. Used to associate this attachment when manage_tgw_routes is true."
  type        = string
  default     = null
}

variable "tgw_resource_share_arn" {
  description = "RAM share ARN when the TGW lives in another account. Null for same-account labs."
  type        = string
  default     = null
}

variable "manage_tgw_routes" {
  description = "Associate this attachment and add a hub-table static route. Works in the same account. Cross-account: leave false and pass the attachment ID back into the network stack."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Create NAT so in-cluster GitOps can reach GitHub. AWS APIs use VPC endpoints."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Single NAT gateway."
  type        = bool
  default     = true
}

variable "enable_eks" {
  description = "Create the EKS cluster."
  type        = bool
  default     = true
}

variable "enable_security_baseline" {
  description = "Create CloudTrail, Config, GuardDuty and Security Hub in this account."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "EKS version."
  type        = string
  default     = "1.31"
}

variable "endpoint_public_access" {
  description = "Public Kubernetes API. Default false. See docs/aws/operations.md."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to the public API when enabled."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_desired_size" {
  description = "Desired worker count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum worker count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum worker count."
  type        = number
  default     = 4
}

variable "allowed_admin_principals" {
  description = "IAM principal ARNs granted EKS cluster-admin."
  type        = list(string)
  default     = []
}

variable "github_org" {
  description = "GitHub organisation or user."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_deploy_environments" {
  description = "GitHub environments allowed to assume the deploy role."
  type        = list(string)
  default     = ["dev"]
}

variable "state_bucket_arn" {
  description = "Terraform state bucket ARN for GitHub plan/deploy roles. Empty when using a local backend."
  type        = string
  default     = ""
}

variable "budget_amount" {
  description = "Example monthly budget in USD."
  type        = number
  default     = 500
}

variable "budget_email" {
  description = "Budget alert email."
  type        = string
  default     = "platform-finops@example.com"
}

locals {
  cluster_name  = "${var.name}-${var.environment}"
  cross_account = var.network_account_id != var.workload_account_id
}

module "tags" {
  source              = "../../modules/aws/tags"
  environment         = var.environment
  owner               = var.owner
  cost_centre         = var.cost_centre
  service             = var.name
  data_classification = "internal"
}

module "kms" {
  source      = "../../modules/aws/kms"
  name        = "${var.name}-${var.environment}-workload"
  description = "Workload key for ${var.name} ${var.environment}"
  tags        = module.tags.tags
}

resource "aws_ram_resource_share_accepter" "tgw" {
  count     = local.cross_account && var.tgw_resource_share_arn != null ? 1 : 0
  share_arn = var.tgw_resource_share_arn
}

module "vpc" {
  source                     = "../../modules/aws/vpc"
  name                       = local.cluster_name
  cidr                       = var.vpc_cidr
  azs                        = var.azs
  create_public_subnets      = true
  enable_nat_gateway         = var.enable_nat_gateway
  single_nat_gateway         = var.single_nat_gateway
  transit_gateway_id         = var.transit_gateway_id
  transit_gateway_routes     = [var.network_hub_cidr]
  allow_default_route_to_tgw = false
  kubernetes_cluster_name    = var.enable_eks ? local.cluster_name : null
  kms_key_arn                = module.kms.key_arn
  tags                       = module.tags.tags

  depends_on = [aws_ram_resource_share_accepter.tgw]
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  count                          = var.manage_tgw_routes && var.transit_gateway_spoke_route_table_id != null ? 1 : 0
  transit_gateway_attachment_id  = module.vpc.tgw_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_spoke_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_hub" {
  count                          = var.manage_tgw_routes && var.transit_gateway_hub_route_table_id != null ? 1 : 0
  transit_gateway_attachment_id  = module.vpc.tgw_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_hub_route_table_id
}

resource "aws_ec2_transit_gateway_route" "hub_to_spoke" {
  count                          = var.manage_tgw_routes && var.transit_gateway_hub_route_table_id != null ? 1 : 0
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = module.vpc.tgw_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_hub_route_table_id
}

module "ecr" {
  source      = "../../modules/aws/ecr"
  name        = "${var.name}/sample-service"
  kms_key_arn = module.kms.key_arn
  tags        = module.tags.tags
}

data "aws_iam_policy_document" "sample_service" {
  statement {
    sid = "ReadExampleSecret"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [module.secrets.secret_arn]
  }
  statement {
    sid = "DecryptSecret"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [module.kms.key_arn]
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "ReadSecretsPrefix"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = [
      module.secrets.secret_arn,
      "arn:aws:secretsmanager:${var.region}:${var.workload_account_id}:secret:/sample-service/*",
    ]
  }
  statement {
    sid       = "DecryptSecrets"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [module.kms.key_arn]
  }
}

module "eks" {
  count                        = var.enable_eks ? 1 : 0
  source                       = "../../modules/aws/eks"
  name                         = local.cluster_name
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.private_subnet_ids
  kms_key_arn                  = module.kms.key_arn
  kubernetes_version           = var.kubernetes_version
  desired_size                 = var.node_desired_size
  min_size                     = var.node_min_size
  max_size                     = var.node_max_size
  endpoint_private_access      = true
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  allowed_admin_principals     = var.allowed_admin_principals
  tags                         = module.tags.tags
  pod_identities = {
    sample-service = {
      namespace       = "sample-service"
      service_account = "sample-service"
      policy_json     = data.aws_iam_policy_document.sample_service.json
    }
    external-secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
      policy_json     = data.aws_iam_policy_document.external_secrets.json
    }
  }
}

module "github_oidc" {
  source              = "../../modules/aws/github-oidc"
  name_prefix         = "${var.name}-${var.environment}"
  github_org          = var.github_org
  github_repo         = var.github_repo
  ecr_repository_arns = [module.ecr.repository_arn]
  state_bucket_arn    = var.state_bucket_arn
  deploy_environments = var.github_deploy_environments
  tags                = module.tags.tags
}

module "secrets" {
  source      = "../../modules/aws/secrets"
  name        = "/sample-service/example-config"
  description = "Harmless example config for the sample service. Replace the placeholder outside Terraform."
  kms_key_arn = module.kms.key_arn
  placeholder = "set-externally"
  tags        = module.tags.tags
}

module "security_baseline" {
  count       = var.enable_security_baseline ? 1 : 0
  source      = "../../modules/aws/security-baseline"
  name        = "${var.name}-${var.environment}"
  kms_key_arn = module.kms.key_arn
  tags        = module.tags.tags
}

module "budgets" {
  source = "../../modules/aws/budgets"
  name   = "${var.name}-${var.environment}"
  amount = var.budget_amount
  email  = var.budget_email
  tags   = module.tags.tags
}

output "vpc_id" {
  description = "Workload VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Workload VPC CIDR."
  value       = module.vpc.vpc_cidr
}

output "tgw_attachment_id" {
  description = "Workload VPC attachment ID. Pass back to the network stack in a cross-account topology."
  value       = module.vpc.tgw_attachment_id
}

output "eks_cluster_name" {
  description = "EKS cluster name, if created."
  value       = try(module.eks[0].cluster_name, null)
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint, if created."
  value       = try(module.eks[0].cluster_endpoint, null)
}

output "ecr_repository_url" {
  description = "Sample service repository URL."
  value       = module.ecr.repository_url
}

output "github_plan_role_arn" {
  description = "GitHub Actions plan role."
  value       = module.github_oidc.plan_role_arn
}

output "github_deploy_role_arn" {
  description = "GitHub Actions deploy role."
  value       = module.github_oidc.deploy_role_arn
}

output "github_publish_role_arn" {
  description = "GitHub Actions image publish role."
  value       = module.github_oidc.publish_role_arn
}

output "github_trust_subjects" {
  description = "OIDC subjects allowed to assume GitHub roles."
  value       = module.github_oidc.trust_subjects
}

output "sample_service_pod_role_arn" {
  description = "EKS Pod Identity role for the sample service."
  value       = try(module.eks[0].pod_identity_role_arns["sample-service"], null)
}

output "example_secret_arn" {
  description = "Secrets Manager ARN for /sample-service/example-config."
  value       = module.secrets.secret_arn
}

output "network_account_id" {
  description = "Network account ID this workload expects to attach to."
  value       = var.network_account_id
}

output "workload_account_id" {
  description = "Workload account ID."
  value       = var.workload_account_id
}

output "management_account_id" {
  description = "Management account ID supplied to this stack. Informational."
  value       = var.management_account_id
}
