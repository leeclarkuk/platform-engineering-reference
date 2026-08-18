terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

resource "aws_s3_bucket" "private_data" {
  bucket        = "platform-ref-private-data-example"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "private_data" {
  bucket                  = aws_s3_bucket.private_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "private_data" {
  bucket = aws_s3_bucket.private_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_data" {
  bucket = aws_s3_bucket.private_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "private_data" {
  bucket        = aws_s3_bucket.private_data.id
  target_bucket = aws_s3_bucket.private_data.id
  target_prefix = "access/"
}

resource "aws_s3_bucket_lifecycle_configuration" "private_data" {
  bucket = aws_s3_bucket.private_data.id
  rule {
    id     = "retain"
    status = "Enabled"
    filter {}
    expiration {
      days = 365
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
