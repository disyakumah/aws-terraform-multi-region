# Bucket Policy for Security Enforcement

data "aws_iam_policy_document" "bucket_policy" {
  # Deny unencrypted object uploads
  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = var.encryption_type == "aws:kms" ? ["aws:kms"] : ["AES256"]
    }
  }

  # Deny insecure transport (require HTTPS)
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Optional: Allow specific IAM principals
  dynamic "statement" {
    for_each = length(var.allowed_principals) > 0 ? [1] : []

    content {
      sid    = "AllowSpecificPrincipals"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.allowed_principals
      }

      actions = var.allowed_actions

      resources = [
        aws_s3_bucket.this.arn,
        "${aws_s3_bucket.this.arn}/*"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.this
  ]
}


# IAM Role for S3 Replication
resource "aws_iam_role" "replication" {
  count = var.enable_replication ? 1 : 0
  name  = "${var.bucket_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.bucket_name}-replication-role"
      Environment = var.environment
    },
    var.tags
  )
}

# IAM Policy for Replication
resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication ? 1 : 0
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.this.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${var.replication_destination_bucket}/*"
      }
    ]
  })
}
