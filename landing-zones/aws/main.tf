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
}

variable "region" {
  description = "Home region for IAM Identity Center and global resources that still need a provider region."
  type        = string
  default     = "eu-west-2"
}

variable "create_organization" {
  description = "Create an AWS Organization. Set false if one already exists."
  type        = bool
  default     = false
}

resource "aws_organizations_organization" "this" {
  count                = var.create_organization ? 1 : 0
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com",
    "backup.amazonaws.com",
    "malware-protection.guardduty.amazonaws.com",
  ]
}

resource "aws_organizations_policy" "deny_access_keys" {
  name        = "deny-iam-access-keys"
  description = "Workload accounts must use federation, not long-lived access keys."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyCreateAccessKey"
        Effect   = "Deny"
        Action   = ["iam:CreateAccessKey", "iam:CreateUser"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "deny-leave-organization"
  description = "Accounts cannot leave the organisation."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeave"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }
    ]
  })
}

output "deny_access_keys_policy_id" {
  description = "SCP ID that denies IAM users and access keys."
  value       = aws_organizations_policy.deny_access_keys.id
}
