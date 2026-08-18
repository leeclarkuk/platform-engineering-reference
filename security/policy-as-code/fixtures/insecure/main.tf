# Deliberately insecure. CI must reject this tree.
# See scripts/test-policy.sh.
resource "aws_s3_bucket" "public_data" {
  bucket = "platform-ref-public-data-do-not-use"
}

resource "aws_s3_bucket_public_access_block" "public_data" {
  bucket                  = aws_s3_bucket.public_data.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "public-read"
}
