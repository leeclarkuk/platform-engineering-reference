mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "222222222222"
      arn        = "arn:aws:iam::222222222222:root"
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-2"
      id     = "eu-west-2"
      name   = "eu-west-2"
    }
  }
}

variables {
  name                = "platform-ref-dev"
  enable_flow_logs    = false
  share_principals    = ["333333333333"]
  allow_default_route = false
  tags = {
    Environment        = "dev"
    Owner              = "platform"
    CostCentre         = "platform-engineering"
    Service            = "network"
    DataClassification = "internal"
    ManagedBy          = "terraform"
  }
}

run "default_tables_disabled" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_association == "disable"
    error_message = "TGW must not auto-associate the default route table."
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_propagation == "disable"
    error_message = "TGW must not auto-propagate the default route table."
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.default_via_hub) == 0
    error_message = "A default 0.0.0.0/0 TGW route must not be created in this slice."
  }
}

run "spoke_static_route_when_attachment_provided" {
  command = plan

  variables {
    spoke_attachments = {
      workload = {
        attachment_id = "tgw-attach-0123456789abcdef0"
        cidr          = "10.20.0.0/16"
      }
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.hub_to_spoke["workload"].destination_cidr_block == "10.20.0.0/16"
    error_message = "Hub route table must contain the workload CIDR."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route_table_association.spoke["workload"].transit_gateway_attachment_id == "tgw-attach-0123456789abcdef0"
    error_message = "Spoke attachment must associate with the spoke route table."
  }
}
