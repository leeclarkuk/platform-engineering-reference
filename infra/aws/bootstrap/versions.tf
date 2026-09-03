terraform {
  # Pin Terraform CLI locally and in CI. This repository uses offline
  # validation only, so the exact CLI version is part of the evidence.
  required_version = "= 1.16.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.62.0"
    }
  }
}

