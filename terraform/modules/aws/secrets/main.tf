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
  description = "Secrets Manager secret name. Use a path such as /sample-service/example-config."
  type        = string
}

variable "description" {
  description = "Secret description."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for the secret."
  type        = string
}

variable "placeholder" {
  description = "Non-secret placeholder written once. Real values are injected outside Terraform and ignored on later applies."
  type        = string
  default     = "set-externally"
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

resource "aws_secretsmanager_secret" "this" {
  # Placeholder contract only. Rotation is an operational process
  # (put-secret-value), not a Lambda in this slice.
  # checkov:skip=CKV2_AWS_57: demonstration secret with no production credential
  name                    = var.name
  description             = var.description
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "placeholder" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    EXAMPLE_CONFIG = var.placeholder
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

output "secret_arn" {
  description = "Secrets Manager secret ARN."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Secrets Manager secret name."
  value       = aws_secretsmanager_secret.this.name
}
