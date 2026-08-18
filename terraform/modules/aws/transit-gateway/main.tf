terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

variable "name" {
  description = "Transit Gateway name."
  type        = string
}

variable "amazon_side_asn" {
  description = "Private ASN for the TGW."
  type        = number
  default     = 64512
}

variable "auto_accept_shared_attachments" {
  description = "Accept attachments from RAM principals automatically. Default disable. Dev labs may set enable so a spoke can attach without a second network apply."
  type        = string
  default     = "disable"
}

variable "share_principals" {
  description = "Account IDs that may attach to this TGW via RAM. Omit the owner account; RAM share is skipped when empty."
  type        = list(string)
  default     = []
}

variable "hub_attachment_id" {
  description = "Network hub VPC attachment ID to associate with the hub route table."
  type        = string
  default     = null
}

variable "hub_cidr" {
  description = "Hub VPC CIDR advertised to spoke attachments as a static route."
  type        = string
  default     = null
}

variable "spoke_attachments" {
  description = "Spoke attachments owned by this TGW. Keys are names. Used for association, propagation and static routes. Empty on the first network apply in a cross-account topology."
  type = map(object({
    attachment_id = string
    cidr          = string
  }))
  default = {}
}

variable "allow_default_route" {
  description = "Create a 0.0.0.0/0 TGW route. Off until hub egress exists."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key for TGW flow log encryption."
  type        = string
  default     = null
}

variable "enable_flow_logs" {
  description = "Enable Transit Gateway flow logs."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

data "aws_caller_identity" "current" {}

locals {
  share_principals = [
    for id in var.share_principals : id if id != data.aws_caller_identity.current.account_id
  ]
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = var.name
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  tags                            = merge(var.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name}-hub" })
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name}-spoke" })
}

resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  count                          = var.hub_attachment_id == null ? 0 : 1
  transit_gateway_attachment_id  = var.hub_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hub" {
  count                          = var.hub_attachment_id == null ? 0 : 1
  transit_gateway_attachment_id  = var.hub_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each                       = var.spoke_attachments
  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_hub" {
  for_each                       = var.spoke_attachments
  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route" "hub_to_spoke" {
  for_each                       = var.spoke_attachments
  destination_cidr_block         = each.value.cidr
  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route" "spoke_to_hub" {
  count                          = var.hub_attachment_id != null && var.hub_cidr != null ? 1 : 0
  destination_cidr_block         = var.hub_cidr
  transit_gateway_attachment_id  = var.hub_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route" "default_via_hub" {
  count = var.allow_default_route && var.hub_attachment_id != null ? 1 : 0

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = var.hub_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ram_resource_share" "tgw" {
  count                     = length(local.share_principals) > 0 ? 1 : 0
  name                      = "${var.name}-tgw"
  allow_external_principals = false
  tags                      = merge(var.tags, { Name = "${var.name}-tgw-share" })
}

resource "aws_ram_resource_association" "tgw" {
  count              = length(local.share_principals) > 0 ? 1 : 0
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "tgw" {
  for_each           = toset(local.share_principals)
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_cloudwatch_log_group" "tgw_flow" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/platform/${var.name}/tgw-flow-logs"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_flow_log" "tgw" {
  count                    = var.enable_flow_logs ? 1 : 0
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.tgw_flow[0].arn
  traffic_type             = "ALL"
  transit_gateway_id       = aws_ec2_transit_gateway.this.id
  max_aggregation_interval = 60
  tags                     = var.tags
}

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN."
  value       = aws_ec2_transit_gateway.this.arn
}

output "hub_route_table_id" {
  description = "Route table for the network hub attachment."
  value       = aws_ec2_transit_gateway_route_table.hub.id
}

output "spoke_route_table_id" {
  description = "Route table for spoke attachments."
  value       = aws_ec2_transit_gateway_route_table.spoke.id
}

output "resource_share_arn" {
  description = "RAM share ARN, if the TGW is shared."
  value       = try(aws_ram_resource_share.tgw[0].arn, null)
}

output "routing_intent" {
  description = "Human-readable routing intent for validation and docs."
  value = {
    default_association    = "disable"
    default_propagation    = "disable"
    default_route          = var.allow_default_route ? "present-via-hub" : "absent"
    hub_associates_with    = "hub"
    spoke_associates_with  = "spoke"
    hub_learns_spoke_cidrs = [for s in var.spoke_attachments : s.cidr]
    spokes_learn_hub_cidr  = var.hub_cidr
    ram_share_principals   = local.share_principals
  }
}
