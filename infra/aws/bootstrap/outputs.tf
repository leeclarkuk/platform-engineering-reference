output "state_bucket_name" {
  value       = aws_s3_bucket.state.bucket
  description = "Terraform state bucket name (bootstrap-only)."
}

output "state_lock_table_name" {
  value       = aws_dynamodb_table.state_lock.name
  description = "Terraform state lock table name (bootstrap-only)."
}

