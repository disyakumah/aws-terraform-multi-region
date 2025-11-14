# Lifecycle Management Configuration

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.this.id

  # Transition to Intelligent-Tiering
  rule {
    id     = "transition-to-intelligent-tiering"
    status = var.lifecycle_intelligent_tiering_days > 0 ? "Enabled" : "Disabled"

    filter {}

    transition {
      days          = var.lifecycle_intelligent_tiering_days
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  # Transition to Glacier
  rule {
    id     = "transition-to-glacier"
    status = var.lifecycle_glacier_days > 0 ? "Enabled" : "Disabled"

    filter {}

    transition {
      days          = var.lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = var.lifecycle_glacier_days
      storage_class   = "GLACIER"
    }
  }

  # Transition to Deep Archive
  rule {
    id     = "transition-to-deep-archive"
    status = var.lifecycle_deep_archive_days > 0 ? "Enabled" : "Disabled"

    filter {}

    transition {
      days          = var.lifecycle_deep_archive_days
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = var.lifecycle_deep_archive_days
      storage_class   = "DEEP_ARCHIVE"
    }
  }

  # Expire non-current versions
  rule {
    id     = "expire-noncurrent-versions"
    status = var.lifecycle_noncurrent_expiration_days > 0 ? "Enabled" : "Disabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_noncurrent_expiration_days
    }
  }

  # Abort incomplete multipart uploads
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
