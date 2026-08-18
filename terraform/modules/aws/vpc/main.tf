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
  description = "Name prefix for VPC resources."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR."
  type        = string
}

variable "azs" {
  description = "Availability zones to use."
  type        = list(string)
}

variable "create_public_subnets" {
  description = "Create public subnets and an internet gateway. Hub VPCs can omit these."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways for private subnets. Prefer centralised egress in production hubs. Required here only when workloads need non-AWS internet (for example Argo CD cloning GitHub)."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway (cheaper, weaker AZ isolation)."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch."
  type        = bool
  default     = true
}

variable "transit_gateway_id" {
  description = "Optional TGW to attach."
  type        = string
  default     = null
}

variable "transit_gateway_routes" {
  description = "CIDRs sent from private (and TGW) route tables to the Transit Gateway. Do not include 0.0.0.0/0 unless allow_default_route_to_tgw is true."
  type        = list(string)
  default     = []
}

variable "allow_default_route_to_tgw" {
  description = "Permit a 0.0.0.0/0 route toward the Transit Gateway. Off unless hub egress is actually implemented."
  type        = bool
  default     = false
}

variable "kubernetes_cluster_name" {
  description = "If set, tag subnets for this EKS cluster."
  type        = string
  default     = null
}

variable "interface_endpoints" {
  description = "Interface VPC endpoint service names (suffix only, for example ecr.api)."
  type        = set(string)
  default = [
    "ecr.api",
    "ecr.dkr",
    "logs",
    "sts",
    "secretsmanager",
    "eks",
    "ec2",
    "kms",
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

variable "kms_key_arn" {
  description = "Optional KMS key for flow log encryption."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
}

locals {
  azs = var.azs

  public_subnets = [
    for i, az in local.azs : cidrsubnet(var.cidr, 4, i)
  ]
  private_subnets = [
    for i, az in local.azs : cidrsubnet(var.cidr, 4, i + 4)
  ]
  tgw_subnets = [
    for i, az in local.azs : cidrsubnet(var.cidr, 8, 192 + i)
  ]

  cluster_tags = var.kubernetes_cluster_name == null ? {} : {
    "kubernetes.io/cluster/${var.kubernetes_cluster_name}" = "shared"
  }

  tgw_cidrs = toset(var.transit_gateway_id == null ? [] : var.transit_gateway_routes)
}

resource "terraform_data" "default_route_guard" {
  lifecycle {
    precondition {
      condition     = var.allow_default_route_to_tgw || !contains(var.transit_gateway_routes, "0.0.0.0/0")
      error_message = "A default route to the Transit Gateway requires allow_default_route_to_tgw = true. This slice does not implement hub egress."
    }
    precondition {
      condition     = !var.enable_nat_gateway || var.create_public_subnets
      error_message = "NAT gateways require public subnets and an internet gateway."
    }
  }
}

data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.name })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-default-sg-locked" })
}

resource "aws_internet_gateway" "this" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = var.create_public_subnets ? length(local.azs) : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, local.cluster_tags, {
    Name                     = "${var.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
    Tier                     = "public"
  })
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = merge(var.tags, local.cluster_tags, {
    Name                              = "${var.name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "private"
  })
}

resource "aws_subnet" "tgw" {
  count             = var.transit_gateway_id == null ? 0 : length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.tgw_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = merge(var.tags, {
    Name = "${var.name}-tgw-${local.azs[count.index]}"
    Tier = "tgw"
  })
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  count                  = var.create_public_subnets ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count          = var.create_public_subnets ? length(local.azs) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway && !var.single_nat_gateway ? length(local.azs) : 1
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-${count.index}" })
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? length(aws_route_table.private) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route" "private_tgw" {
  for_each = {
    for pair in flatten([
      for rt_idx, _rt in aws_route_table.private : [
        for cidr in local.tgw_cidrs : {
          key    = "${rt_idx}:${cidr}"
          rt_idx = rt_idx
          cidr   = cidr
        }
      ]
    ]) : pair.key => pair
  }

  route_table_id         = aws_route_table.private[each.value.rt_idx].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway || !var.enable_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table" "tgw" {
  count  = var.transit_gateway_id == null ? 0 : 1
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-tgw" })
}

resource "aws_route" "tgw_to_hub_or_spokes" {
  for_each = var.transit_gateway_id == null ? toset([]) : local.tgw_cidrs

  route_table_id         = aws_route_table.tgw[0].id
  destination_cidr_block = each.value
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table_association" "tgw" {
  count          = var.transit_gateway_id == null ? 0 : length(local.azs)
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[0].id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count              = var.transit_gateway_id == null ? 0 : 1
  subnet_ids         = aws_subnet.tgw[*].id
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id

  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, { Name = "${var.name}-tgw-attach" })
}

resource "aws_cloudwatch_log_group" "flow" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/platform/${var.name}/vpc-flow-logs"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "flow_assume" {
  count = var.enable_flow_logs ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  count              = var.enable_flow_logs ? 1 : 0
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow" {
  count = var.enable_flow_logs ? 1 : 0
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  count  = var.enable_flow_logs ? 1 : 0
  name   = "cloudwatch"
  role   = aws_iam_role.flow[0].id
  policy = data.aws_iam_policy_document.flow[0].json
}

resource "aws_flow_log" "this" {
  count                    = var.enable_flow_logs ? 1 : 0
  iam_role_arn             = aws_iam_role.flow[0].arn
  log_destination          = aws_cloudwatch_log_group.flow[0].arn
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.this.id
  max_aggregation_interval = 60
  tags                     = var.tags
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-vpce"
  description = "VPC interface endpoints"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name}-vpce" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS from VPC"
  cidr_ipv4         = var.cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "endpoints_all" {
  security_group_id = aws_security_group.endpoints.id
  description       = "Allow egress from endpoint ENIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = compact(concat(
    aws_route_table.public[*].id,
    aws_route_table.private[*].id,
    aws_route_table.tgw[*].id,
  ))
  tags = merge(var.tags, { Name = "${var.name}-s3" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "tgw_subnet_ids" {
  description = "Transit Gateway attachment subnet IDs."
  value       = aws_subnet.tgw[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = aws_route_table.private[*].id
}

output "tgw_attachment_id" {
  description = "Transit Gateway VPC attachment ID, if created."
  value       = try(aws_ec2_transit_gateway_vpc_attachment.this[0].id, null)
}

output "endpoint_security_group_id" {
  description = "Security group used by interface endpoints."
  value       = aws_security_group.endpoints.id
}

output "transit_gateway_routes" {
  description = "CIDRs routed to the Transit Gateway from this VPC."
  value       = sort(var.transit_gateway_routes)
}
