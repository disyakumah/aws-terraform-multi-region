# S3 Bucket Module - AWS Best Practices 2025
# This module creates a secure S3 bucket with encryption, versioning, and lifecycle policies

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary S3 Bucket Resource
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    {
      Name        = var.bucket_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Server-Side Encryption Configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type == "aws:kms" ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_type == "aws:kms" ? var.kms_key_id : null
    }
    bucket_key_enabled = var.encryption_type == "aws:kms" ? true : false
  }
}

# Public Access Block Configuration
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning Configuration
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

# Access Logging Configuration
resource "aws_s3_bucket_logging" "this" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_bucket_name
  target_prefix = "${var.bucket_name}/"
}

# Cross-Region Replication Configuration
resource "aws_s3_bucket_replication_configuration" "this" {
  count  = var.enable_replication ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    filter {}

    destination {
      bucket        = var.replication_destination_bucket
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.this
  ]
}
