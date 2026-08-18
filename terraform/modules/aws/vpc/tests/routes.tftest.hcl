mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-2"
      id     = "eu-west-2"
      name   = "eu-west-2"
    }
  }
}

variables {
  name                       = "platform-ref-dev"
  cidr                       = "10.20.0.0/16"
  azs                        = ["eu-west-2a", "eu-west-2b"]
  create_public_subnets      = true
  enable_nat_gateway         = false
  transit_gateway_id         = "tgw-0123456789abcdef0"
  transit_gateway_routes     = ["10.10.0.0/16"]
  allow_default_route_to_tgw = false
  interface_endpoints        = []
  enable_flow_logs           = false
  tags = {
    Environment        = "dev"
    Owner              = "platform"
    CostCentre         = "platform-engineering"
    Service            = "workload"
    DataClassification = "internal"
    ManagedBy          = "terraform"
  }
}

run "private_subnets_have_no_public_ip" {
  command = plan

  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == false
    error_message = "Public subnets must not auto-assign public IPs."
  }

  assert {
    condition     = length(aws_route.private_nat) == 0
    error_message = "NAT default routes should be absent when NAT is disabled."
  }

  assert {
    condition     = contains(values(aws_route.private_tgw)[*].destination_cidr_block, "10.10.0.0/16")
    error_message = "Private route tables must send the hub CIDR to the Transit Gateway."
  }

  assert {
    condition     = !contains(values(aws_route.private_tgw)[*].destination_cidr_block, "0.0.0.0/0")
    error_message = "Private route tables must not send the default route to the Transit Gateway."
  }
}

run "reject_unapproved_default_tgw_route" {
  command = plan

  variables {
    transit_gateway_routes     = ["0.0.0.0/0"]
    allow_default_route_to_tgw = false
  }

  expect_failures = [terraform_data.default_route_guard]
}
