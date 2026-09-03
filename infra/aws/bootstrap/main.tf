# Bootstrap root: state/bootstrap prerequisites only.
# No live application resources are modelled in Milestone 2.

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
  acl    = "private"

  force_destroy = false

  tags = {
    purpose = "terraform-state"
  }
}

resource "aws_dynamodb_table" "state_lock" {
  name         = var.state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    purpose = "terraform-state-lock"
  }
}

