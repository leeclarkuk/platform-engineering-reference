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
  allowed_account_ids = compact([var.network_account_id])

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
  description = "Organisation management account ID. Not used to create the organisation."
  type        = string
}

variable "network_account_id" {
  description = "Account that owns the Transit Gateway and hub VPC."
  type        = string
}

variable "workload_account_id" {
  description = "Account that will attach the workload VPC. Shared via RAM when different from the network account."
  type        = string
}

variable "hub_cidr" {
  description = "Hub VPC CIDR."
  type        = string
}

variable "workload_cidr" {
  description = "Expected workload VPC CIDR. Used for hub VPC routes toward the TGW. TGW static routes to this CIDR also need the spoke attachment ID."
  type        = string
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
}

variable "private_dns_domain" {
  description = "Private hosted zone name associated with the hub VPC."
  type        = string
  default     = "platform.internal"
}

variable "spoke_attachments" {
  description = "Spoke TGW attachments to associate after they exist. Empty on the first apply."
  type = map(object({
    attachment_id = string
    cidr          = string
  }))
  default = {}
}

variable "auto_accept_shared_attachments" {
  description = "enable or disable. disable is the safe default. enable avoids a second accept step in a lab."
  type        = string
  default     = "disable"
}

module "tags" {
  source              = "../../modules/aws/tags"
  environment         = var.environment
  owner               = var.owner
  cost_centre         = var.cost_centre
  service             = "${var.name}-network"
  data_classification = "internal"
}

module "kms" {
  source      = "../../modules/aws/kms"
  name        = "${var.name}-${var.environment}-network"
  description = "Network hub key for ${var.name} ${var.environment}"
  tags        = module.tags.tags
}

module "tgw" {
  source                         = "../../modules/aws/transit-gateway"
  name                           = "${var.name}-${var.environment}"
  auto_accept_shared_attachments = var.auto_accept_shared_attachments
  share_principals               = [var.workload_account_id]
  hub_cidr                       = var.hub_cidr
  spoke_attachments              = var.spoke_attachments
  allow_default_route            = false
  kms_key_arn                    = module.kms.key_arn
  tags                           = module.tags.tags
}

module "vpc" {
  source                     = "../../modules/aws/vpc"
  name                       = "${var.name}-${var.environment}-hub"
  cidr                       = var.hub_cidr
  azs                        = var.azs
  create_public_subnets      = false
  enable_nat_gateway         = false
  transit_gateway_id         = module.tgw.transit_gateway_id
  transit_gateway_routes     = [var.workload_cidr]
  allow_default_route_to_tgw = false
  interface_endpoints        = ["logs"]
  kms_key_arn                = module.kms.key_arn
  tags                       = module.tags.tags
}

resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = module.vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.hub_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hub_to_spoke" {
  transit_gateway_attachment_id  = module.vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.spoke_route_table_id
}

resource "aws_ec2_transit_gateway_route" "spoke_to_hub" {
  destination_cidr_block         = var.hub_cidr
  transit_gateway_attachment_id  = module.vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.spoke_route_table_id
}

resource "aws_route53_zone" "internal" {
  name = var.private_dns_domain
  vpc {
    vpc_id = module.vpc.vpc_id
  }
  tags = merge(module.tags.tags, { Name = var.private_dns_domain })
}

output "transit_gateway_id" {
  description = "Transit Gateway ID. Pass to the workload stack."
  value       = module.tgw.transit_gateway_id
}

output "hub_vpc_id" {
  description = "Hub VPC ID."
  value       = module.vpc.vpc_id
}

output "hub_cidr" {
  description = "Hub VPC CIDR."
  value       = var.hub_cidr
}

output "hub_attachment_id" {
  description = "Hub VPC TGW attachment ID."
  value       = module.vpc.tgw_attachment_id
}

output "hub_route_table_id" {
  description = "TGW route table for the hub attachment."
  value       = module.tgw.hub_route_table_id
}

output "spoke_route_table_id" {
  description = "TGW route table for spoke attachments. Pass to the workload stack in a same-account lab."
  value       = module.tgw.spoke_route_table_id
}

output "private_hosted_zone_id" {
  description = "Private hosted zone in the hub VPC. Associate spoke VPCs in a later apply."
  value       = aws_route53_zone.internal.zone_id
}

output "routing_intent" {
  description = "Routing intent from the TGW module plus hub VPC routes."
  value = merge(module.tgw.routing_intent, {
    hub_vpc_routes_to = var.workload_cidr
    default_route     = "absent"
  })
}

output "management_account_id" {
  description = "Management account ID supplied to this stack. Informational."
  value       = var.management_account_id
}

output "network_account_id" {
  description = "Network account ID this stack must run in."
  value       = var.network_account_id
}

output "workload_account_id" {
  description = "Workload account ID that may attach to the TGW."
  value       = var.workload_account_id
}
