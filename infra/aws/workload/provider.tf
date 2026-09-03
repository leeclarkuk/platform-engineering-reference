variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for offline Terraform configuration validation."
}

provider "aws" {
  region = var.aws_region

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

