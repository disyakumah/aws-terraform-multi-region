# S3 Bucket - Essame
module "s3_bucket_essame" {
  source = "./modules/s3-bucket"

  providers = {
    aws = aws.us_west
  }

  bucket_name = "essame"
  environment = var.environment

  # Security settings
  enable_encryption = true
  encryption_type   = "AES256"
  enable_versioning = true

  # Lifecycle management
  enable_lifecycle                     = true
  lifecycle_intelligent_tiering_days   = 30
  lifecycle_glacier_days               = 90
  lifecycle_deep_archive_days          = 180
  lifecycle_noncurrent_expiration_days = 365

  # Optional: Enable logging (requires a logging bucket)
  enable_logging      = false
  logging_bucket_name = null

  tags = {
    Name        = "essame"
    Environment = var.environment
    Region      = "us-west-2"
    Owner       = "Platform Team"
    Project     = "Core Infrastructure"
  }
}
