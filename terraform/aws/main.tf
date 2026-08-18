terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = var.region

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

variable "vpc_cidr" {
  description = "Spoke VPC CIDR."
  type        = string
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create NAT in this VPC. Production should usually egress via the hub instead."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Single NAT gateway."
  type        = bool
  default     = true
}

variable "create_transit_gateway" {
  description = "Create a TGW in this composition. In a real estate the TGW lives in the network account."
  type        = bool
  default     = false
}

variable "transit_gateway_id" {
  description = "Existing TGW ID when not creating one."
  type        = string
  default     = null
}

variable "enable_eks" {
  description = "Create an EKS cluster."
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

variable "node_desired_size" {
  description = "Desired worker count."
  type        = number
  default     = 2
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

module "tags" {
  source              = "../modules/aws/tags"
  environment         = var.environment
  owner               = var.owner
  cost_centre         = var.cost_centre
  service             = var.name
  data_classification = "internal"
}

module "kms" {
  source      = "../modules/aws/kms"
  name        = "${var.name}-${var.environment}"
  description = "Platform key for ${var.name} ${var.environment}"
  tags        = module.tags.tags
}

module "tgw" {
  count  = var.create_transit_gateway ? 1 : 0
  source = "../modules/aws/transit-gateway"
  name   = "${var.name}-${var.environment}"
  tags   = module.tags.tags
}

locals {
  transit_gateway_id = var.create_transit_gateway ? module.tgw[0].transit_gateway_id : var.transit_gateway_id
}

module "vpc" {
  source             = "../modules/aws/vpc"
  name               = "${var.name}-${var.environment}"
  cidr               = var.vpc_cidr
  azs                = var.azs
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  transit_gateway_id = local.transit_gateway_id
  kms_key_arn        = module.kms.key_arn
  tags               = module.tags.tags
}

module "ecr" {
  source      = "../modules/aws/ecr"
  name        = "${var.name}/sample-service"
  kms_key_arn = module.kms.key_arn
  tags        = module.tags.tags
}

module "eks" {
  count              = var.enable_eks ? 1 : 0
  source             = "../modules/aws/eks"
  name               = "${var.name}-${var.environment}"
  subnet_ids         = module.vpc.private_subnet_ids
  kms_key_arn        = module.kms.key_arn
  kubernetes_version = var.kubernetes_version
  desired_size       = var.node_desired_size
  tags               = module.tags.tags
}

module "security_baseline" {
  count       = var.enable_security_baseline ? 1 : 0
  source      = "../modules/aws/security-baseline"
  name        = "${var.name}-${var.environment}"
  kms_key_arn = module.kms.key_arn
  tags        = module.tags.tags
}

module "budgets" {
  source = "../modules/aws/budgets"
  name   = "${var.name}-${var.environment}"
  amount = var.budget_amount
  email  = var.budget_email
  tags   = module.tags.tags
}

output "vpc_id" {
  description = "Workload VPC ID."
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name, if created."
  value       = try(module.eks[0].cluster_name, null)
}

output "ecr_repository_url" {
  description = "Sample service repository URL."
  value       = module.ecr.repository_url
}
