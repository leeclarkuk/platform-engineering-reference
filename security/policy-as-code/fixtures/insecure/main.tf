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

resource "aws_iam_policy" "wildcard_admin" {
  name = "platform-ref-wildcard-admin-do-not-use"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "public_ssh" {
  name        = "platform-ref-public-ssh-do-not-use"
  description = "Deliberately open SSH to the world"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
