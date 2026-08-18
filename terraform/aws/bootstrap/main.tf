terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Partial backend. Local validation uses: terraform init -backend=false
  # Production: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = module.tags.tags
  }
}

variable "region" {
  description = "AWS region for the state bucket."
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

variable "account_id" {
  description = "Account that will own this state bucket. Used only for naming examples and allowed_account_ids."
  type        = string
}

variable "allowed_account_ids" {
  description = "Refuse to run against any other account."
  type        = list(string)
}

variable "create_legacy_lock_table" {
  description = "Create a DynamoDB lock table for Terraform < 1.10. Prefer S3 native lockfile."
  type        = bool
  default     = false
}

module "tags" {
  source              = "../../modules/aws/tags"
  environment         = var.environment
  owner               = var.owner
  cost_centre         = var.cost_centre
  service             = "${var.name}-tfstate"
  data_classification = "internal"
}

module "kms" {
  source      = "../../modules/aws/kms"
  name        = "${var.name}-${var.environment}-tfstate"
  description = "Terraform state encryption for ${var.name} ${var.environment}"
  tags        = module.tags.tags
}

resource "aws_s3_bucket" "state" {
  bucket        = "${var.name}-${var.environment}-tfstate-${var.account_id}"
  force_destroy = false
  tags          = merge(module.tags.tags, { Name = "${var.name}-${var.environment}-tfstate" })
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.kms.key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.state.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "retain-old-state"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "state" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json
}

resource "aws_dynamodb_table" "lock" {
  count        = var.create_legacy_lock_table ? 1 : 0
  name         = "${var.name}-${var.environment}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  tags         = module.tags.tags

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = module.kms.key_arn
  }

  point_in_time_recovery {
    enabled = true
  }
}

output "state_bucket" {
  description = "S3 bucket that holds Terraform state."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "State bucket ARN."
  value       = aws_s3_bucket.state.arn
}

output "state_kms_key_arn" {
  description = "KMS key used to encrypt state."
  value       = module.kms.key_arn
}

output "legacy_lock_table" {
  description = "DynamoDB lock table name, if created."
  value       = try(aws_dynamodb_table.lock[0].name, null)
}
