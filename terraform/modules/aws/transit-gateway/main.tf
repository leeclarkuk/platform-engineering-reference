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
  description = "Transit Gateway name."
  type        = string
}

variable "amazon_side_asn" {
  description = "Private ASN for the TGW."
  type        = number
  default     = 64512
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = var.name
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  tags                            = merge(var.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name}-inspection" })
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name}-spoke" })
}

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "spoke_route_table_id" {
  description = "Route table for spoke attachments."
  value       = aws_ec2_transit_gateway_route_table.spoke.id
}

output "inspection_route_table_id" {
  description = "Route table for inspection/egress attachment."
  value       = aws_ec2_transit_gateway_route_table.inspection.id
}
