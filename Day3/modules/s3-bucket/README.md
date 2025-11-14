# S3 Bucket Module - AWS Best Practices 2025

This Terraform module creates a secure AWS S3 bucket following 2025 best practices with encryption, versioning, lifecycle policies, and optional cross-region replication.

## Features

- **Security by Default**: Encryption enabled, public access blocked, bucket owner enforced
- **Versioning**: Preserve and recover object versions with optional MFA delete
- **Lifecycle Management**: Automatic transitions to cost-effective storage classes
- **Access Logging**: Track all bucket access requests
- **Cross-Region Replication**: Optional data redundancy across regions
- **Restrictive Policies**: Deny unencrypted uploads and insecure transport

## Usage

### Basic Example

```hcl
module "s3_bucket" {
  source = "./modules/s3-bucket"

  bucket_name = "essame"
  environment = "prod"

  tags = {
    Owner   = "DevOps Team"
    Project = "Infrastructure"
  }
}
```

### Advanced Example with All Features

```hcl
module "s3_bucket_advanced" {
  source = "./modules/s3-bucket"

  bucket_name = "essame"
  environment = "prod"

  # Encryption
  enable_encryption = true
  encryption_type   = "AES256"

  # Versioning
  enable_versioning = true
  enable_mfa_delete = false

  # Logging
  enable_logging      = true
  logging_bucket_name = "my-logs-bucket"

  # Lifecycle
  enable_lifecycle                    = true
  lifecycle_intelligent_tiering_days  = 30
  lifecycle_glacier_days              = 90
  lifecycle_deep_archive_days         = 180
  lifecycle_noncurrent_expiration_days = 365

  # Replication (optional)
  enable_replication              = false
  replication_destination_bucket  = "arn:aws:s3:::destination-bucket"
  replication_destination_region  = "us-east-1"

  # Access Control
  allowed_principals = ["arn:aws:iam::123456789012:role/MyRole"]
  allowed_actions    = ["s3:GetObject", "s3:ListBucket"]

  tags = {
    Owner   = "DevOps Team"
    Project = "Infrastructure"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Prerequisites

- **Logging Bucket**: If `enable_logging` is true, ensure the logging bucket exists and has appropriate permissions
- **KMS Key**: If using `encryption_type = "aws:kms"`, provide a valid `kms_key_id`
- **Destination Bucket**: If `enable_replication` is true, ensure the destination bucket exists with versioning enabled

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| bucket_name | The name of the S3 bucket (must be globally unique) | string | - | yes |
| environment | Environment name (dev, staging, prod) | string | - | yes |
| enable_encryption | Enable server-side encryption | bool | true | no |
| encryption_type | Type of encryption (AES256 or aws:kms) | string | "AES256" | no |
| kms_key_id | KMS key ID for SSE-KMS encryption | string | null | no |
| enable_versioning | Enable versioning | bool | true | no |
| enable_mfa_delete | Enable MFA delete protection | bool | false | no |
| enable_logging | Enable access logging | bool | false | no |
| logging_bucket_name | Bucket to store access logs | string | null | no |
| enable_lifecycle | Enable lifecycle policies | bool | true | no |
| lifecycle_intelligent_tiering_days | Days before transitioning to Intelligent-Tiering | number | 30 | no |
| lifecycle_glacier_days | Days before transitioning to Glacier | number | 90 | no |
| lifecycle_deep_archive_days | Days before transitioning to Deep Archive | number | 180 | no |
| lifecycle_noncurrent_expiration_days | Days before expiring non-current versions | number | 365 | no |
| enable_replication | Enable cross-region replication | bool | false | no |
| replication_destination_bucket | ARN of destination bucket for replication | string | null | no |
| replication_destination_region | Region of destination bucket | string | null | no |
| allowed_principals | IAM principal ARNs allowed to access bucket | list(string) | [] | no |
| allowed_actions | S3 actions allowed for specified principals | list(string) | ["s3:GetObject", "s3:ListBucket"] | no |
| force_destroy | Allow deletion of non-empty bucket | bool | false | no |
| tags | Additional tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | The name of the bucket |
| bucket_arn | The ARN of the bucket |
| bucket_domain_name | The bucket domain name |
| bucket_regional_domain_name | The bucket region-specific domain name |
| bucket_hosted_zone_id | The Route 53 hosted zone ID |
| replication_role_arn | IAM role ARN for replication (if enabled) |

## Security Features

### Encryption
- Default encryption using AES-256 (SSE-S3) or AWS KMS
- Bucket policy denies unencrypted object uploads

### Public Access
- All four public access block settings enabled
- Prevents accidental public exposure

### Secure Transport
- Bucket policy requires HTTPS for all requests
- Denies HTTP connections

### Ownership
- Bucket owner enforced ownership
- ACLs disabled for simplified permissions

## Cost Optimization

The module includes lifecycle policies to automatically transition objects to cheaper storage classes:

1. **Intelligent-Tiering** (30 days): Automatic cost savings based on access patterns
2. **Glacier** (90 days): Long-term archival storage
3. **Deep Archive** (180 days): Lowest-cost archival storage
4. **Expiration** (365 days): Delete non-current versions

Incomplete multipart uploads are automatically aborted after 7 days.

## Compliance

- **Versioning**: Enabled by default for data recovery
- **Logging**: Optional access logging for audit trails
- **Encryption**: Enforced through bucket policies
- **Tagging**: Mandatory tags for cost allocation and tracking

## Examples

### Creating a Bucket Named "Essame"

```hcl
module "essame_bucket" {
  source = "./modules/s3-bucket"

  bucket_name = "essame"
  environment = "prod"

  enable_encryption = true
  enable_versioning = true
  enable_lifecycle  = true

  tags = {
    Owner   = "Platform Team"
    Project = "Core Infrastructure"
  }
}
```

## Notes

- S3 bucket names must be globally unique across all AWS accounts
- Bucket names must be 3-63 characters, lowercase, and contain only letters, numbers, and hyphens
- When using KMS encryption, ensure the KMS key policy allows S3 to use the key
- For replication, both source and destination buckets must have versioning enabled
- MFA delete requires MFA to be configured on the AWS account

## License

This module is provided as-is for infrastructure management purposes.
