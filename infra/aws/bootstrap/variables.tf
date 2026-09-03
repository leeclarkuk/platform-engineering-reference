variable "state_bucket_name" {
  type        = string
  description = <<EOT
Bootstrap-only S3 bucket name for eventual Terraform remote state.

Milestone 2 must not commit a live bucket name. This variable has no
default, so the repo never contains a real bucket name.
EOT
}

variable "state_lock_table_name" {
  type        = string
  description = "Bootstrap-only DynamoDB table name for Terraform state locking."
}

