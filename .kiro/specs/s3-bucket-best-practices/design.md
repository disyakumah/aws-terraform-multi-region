# Design Document - S3 Bucket with AWS Best Practices

## Overview

This design outlines a Terraform module for creating AWS S3 buckets following 2025 best practices. The module will be structured as a reusable component that can be integrated into the existing multi-region infrastructure. It will provide comprehensive security controls, encryption, versioning, lifecycle management, and optional replication capabilities.

The module will be designed to work alongside the existing VPC, security group, and EC2 modules in the Day3 directory structure, maintaining consistency with the current architecture patterns.

## Architecture

### Module Structure

```
Day3/
├── modules/
│   └── s3-bucket/
│       ├── main.tf           # Primary S3 bucket resource and configurations
│       ├── variables.tf      # Input variables with validation
│       ├── outputs.tf        # Output values for bucket attributes
│       ├── policies.tf       # Bucket policies and IAM roles
│       ├── lifecycle.tf      # Lifecycle rules configuration
│       └── README.md         # Module documentation
```

### Design Principles

1. **Security by Default**: All security features enabled unless explicitly disabled
2. **Least Privilege**: Restrictive policies that can be relaxed through variables
3. **Cost Optimization**: Built-in lifecycle policies for storage class transitions
4. **Compliance Ready**: Logging, versioning, and encryption enabled by default
5. **Reusability**: Configurable through variables for different use cases

## Components and Interfaces

### 1. S3 Bucket Resource (main.tf)

**Primary Resource**: `aws_s3_bucket`
- Bucket naming with environment and region prefixes
- Force destroy option (disabled by default for safety)
- Tags propagation

**Associated Resources**:
- `aws_s3_bucket_versioning`: Enable versioning with optional MFA delete
- `aws_s3_bucket_server_side_encryption_configuration`: Default encryption (SSE-S3 or SSE-KMS)
- `aws_s3_bucket_public_access_block`: Block all public access
- `aws_s3_bucket_ownership_controls`: Enforce bucket owner ownership
- `aws_s3_bucket_logging`: Server access logging configuration
- `aws_s3_bucket_lifecycle_configuration`: Lifecycle rules for transitions and expiration
- `aws_s3_bucket_replication_configuration`: Optional cross-region replication
- `aws_s3_bucket_intelligent_tiering_configuration`: Optional intelligent tiering

### 2. Bucket Policies (policies.tf)

**Bucket Policy Components**:
```hcl
- Deny unencrypted object uploads (enforce SSL/TLS)
- Deny insecure transport (require HTTPS)
- Optional: Allow specific IAM principals
- Optional: Allow cross-account access
```

**IAM Role for Replication** (when enabled):
- Trust relationship with S3 service
- Permissions to replicate objects, delete markers, and encrypted content
- Permissions to read source bucket and write to destination bucket

### 3. Lifecycle Configuration (lifecycle.tf)

**Lifecycle Rules**:
- Transition to Intelligent-Tiering after 30 days (configurable)
- Transition to Glacier after 90 days (configurable)
- Transition to Deep Archive after 180 days (configurable)
- Expire non-current versions after 365 days (configurable)
- Abort incomplete multipart uploads after 7 days
- Support for prefix and tag-based filtering

### 4. Variables (variables.tf)

**Required Variables**:
- `bucket_name`: Unique bucket name
- `environment`: Environment tag (dev, staging, prod)

**Optional Variables with Defaults**:
- `enable_versioning`: bool (default: true)
- `enable_encryption`: bool (default: true)
- `encryption_type`: string (default: "AES256", options: "AES256", "aws:kms")
- `kms_key_id`: string (default: null)
- `enable_logging`: bool (default: true)
- `logging_bucket_name`: string (default: null)
- `enable_lifecycle`: bool (default: true)
- `lifecycle_rules`: object (default: standard transitions)
- `enable_replication`: bool (default: false)
- `replication_destination_bucket`: string (default: null)
- `replication_destination_region`: string (default: null)
- `enable_intelligent_tiering`: bool (default: false)
- `force_destroy`: bool (default: false)
- `tags`: map(string) (default: {})

**Variable Validation**:
- Bucket name must follow S3 naming conventions (3-63 chars, lowercase, no underscores)
- KMS key ID required when encryption_type is "aws:kms"
- Replication destination required when replication enabled
- Logging bucket name required when logging enabled

### 5. Outputs (outputs.tf)

```hcl
- bucket_id: The name of the bucket
- bucket_arn: The ARN of the bucket
- bucket_domain_name: The bucket domain name
- bucket_regional_domain_name: The bucket region-specific domain name
- bucket_hosted_zone_id: The Route 53 hosted zone ID
- replication_role_arn: IAM role ARN for replication (if enabled)
```

## Data Models

### Lifecycle Rule Structure

```hcl
lifecycle_rule = {
  id      = string
  enabled = bool
  prefix  = string (optional)
  tags    = map(string) (optional)
  
  transitions = [
    {
      days          = number
      storage_class = string  # STANDARD_IA, INTELLIGENT_TIERING, GLACIER, DEEP_ARCHIVE
    }
  ]
  
  expiration = {
    days = number
  }
  
  noncurrent_version_transitions = [
    {
      days          = number
      storage_class = string
    }
  ]
  
  noncurrent_version_expiration = {
    days = number
  }
}
```

### Replication Configuration Structure

```hcl
replication_config = {
  role_arn = string
  
  rules = [
    {
      id       = string
      status   = string  # "Enabled" or "Disabled"
      priority = number
      
      destination = {
        bucket        = string  # ARN of destination bucket
        storage_class = string  # STANDARD, REDUCED_REDUNDANCY, STANDARD_IA, etc.
        
        encryption_configuration = {
          replica_kms_key_id = string (optional)
        }
      }
      
      source_selection_criteria = {
        sse_kms_encrypted_objects = {
          enabled = bool
        }
      }
      
      delete_marker_replication = {
        status = string  # "Enabled" or "Disabled"
      }
    }
  ]
}
```

## Error Handling

### Terraform Validation

1. **Pre-apply Validation**:
   - Variable validation blocks for input constraints
   - Conditional resource creation using `count` or `for_each`
   - Dependency management using `depends_on`

2. **Bucket Name Conflicts**:
   - Use `random_id` or timestamp suffix for uniqueness if needed
   - Provide clear error messages for naming violations

3. **Permission Errors**:
   - Document required IAM permissions for Terraform execution
   - Graceful handling of insufficient permissions with error messages

4. **Replication Prerequisites**:
   - Validate versioning is enabled before allowing replication
   - Check destination bucket exists and is accessible
   - Verify IAM role has necessary permissions

### Runtime Considerations

1. **Encryption Key Access**:
   - Validate KMS key exists and is accessible
   - Handle cross-account KMS key scenarios

2. **Logging Bucket**:
   - Ensure logging bucket exists before enabling logging
   - Verify logging bucket has appropriate ACL/policy

3. **State Management**:
   - Use `prevent_destroy` lifecycle rule for production buckets
   - Document state import procedures for existing buckets

## Testing Strategy

### Unit Testing (Terraform Validation)

1. **Syntax and Format**:
   ```bash
   terraform fmt -check
   terraform validate
   ```

2. **Variable Validation**:
   - Test with valid and invalid bucket names
   - Test encryption configurations
   - Test lifecycle rule combinations

### Integration Testing

1. **Module Testing with terraform-compliance or Terratest**:
   - Verify bucket is created with correct configuration
   - Validate encryption is enabled
   - Confirm public access is blocked
   - Check versioning status
   - Verify lifecycle rules are applied
   - Test replication configuration (if enabled)

2. **Policy Testing**:
   - Attempt unencrypted upload (should fail)
   - Attempt HTTP access (should fail)
   - Verify authorized access works
   - Test cross-account access (if configured)

3. **Multi-Region Testing**:
   - Deploy buckets in multiple regions using different providers
   - Test replication between regions
   - Verify regional configurations

### Security Testing

1. **AWS Config Rules**:
   - s3-bucket-public-read-prohibited
   - s3-bucket-public-write-prohibited
   - s3-bucket-ssl-requests-only
   - s3-bucket-server-side-encryption-enabled
   - s3-bucket-versioning-enabled
   - s3-bucket-logging-enabled

2. **Manual Security Checks**:
   - Verify no public access through AWS Console
   - Check bucket policy denies insecure transport
   - Validate encryption settings
   - Review IAM roles and permissions

### Cost Validation

1. **Lifecycle Policy Testing**:
   - Upload test objects and verify transitions occur
   - Monitor storage class changes over time
   - Validate expiration rules delete objects as expected

2. **Cost Estimation**:
   - Use `terraform plan` with cost estimation tools
   - Document expected costs for different configurations

## Integration with Existing Infrastructure

### Usage in main.tf

```hcl
# Example: Create S3 bucket in us-west-2
module "s3_bucket_us_west" {
  source = "./modules/s3-bucket"
  
  providers = {
    aws = aws.us_west
  }
  
  bucket_name = "${var.environment}-data-bucket-us-west-2"
  environment = var.environment
  
  enable_versioning = true
  enable_encryption = true
  encryption_type   = "AES256"
  
  enable_logging      = true
  logging_bucket_name = "${var.environment}-logs-us-west-2"
  
  enable_lifecycle = true
  lifecycle_rules = {
    intelligent_tiering_days = 30
    glacier_days            = 90
    deep_archive_days       = 180
    noncurrent_expiration_days = 365
  }
  
  tags = {
    Name        = "${var.environment}-data-bucket-us-west-2"
    Environment = var.environment
    Region      = "us-west-2"
    ManagedBy   = "Terraform"
  }
}

# Optional: Enable replication to us-east-1
module "s3_bucket_us_east_replica" {
  source = "./modules/s3-bucket"
  
  providers = {
    aws = aws.us_east
  }
  
  bucket_name = "${var.environment}-data-bucket-us-east-1-replica"
  environment = var.environment
  
  enable_versioning = true
  enable_encryption = true
  
  tags = {
    Name        = "${var.environment}-data-bucket-us-east-1-replica"
    Environment = var.environment
    Region      = "us-east-1"
    Type        = "Replica"
    ManagedBy   = "Terraform"
  }
}

# Configure replication on source bucket
resource "aws_s3_bucket_replication_configuration" "us_west_to_us_east" {
  provider = aws.us_west
  
  bucket = module.s3_bucket_us_west.bucket_id
  role   = module.s3_bucket_us_west.replication_role_arn
  
  rule {
    id     = "replicate-all"
    status = "Enabled"
    
    destination {
      bucket        = module.s3_bucket_us_east_replica.bucket_arn
      storage_class = "STANDARD"
    }
  }
  
  depends_on = [
    module.s3_bucket_us_west,
    module.s3_bucket_us_east_replica
  ]
}
```

### Outputs Integration

Add to root `outputs.tf`:
```hcl
output "s3_buckets" {
  description = "S3 bucket information"
  value = {
    us_west = {
      id          = module.s3_bucket_us_west.bucket_id
      arn         = module.s3_bucket_us_west.bucket_arn
      domain_name = module.s3_bucket_us_west.bucket_domain_name
    }
  }
}
```

## Best Practices Implemented

1. **Security**:
   - Encryption at rest (SSE-S3 or SSE-KMS)
   - Encryption in transit (HTTPS only)
   - Public access blocked
   - Bucket owner enforced
   - Restrictive bucket policies

2. **Compliance**:
   - Versioning enabled
   - Access logging enabled
   - Object lock support (optional)
   - Audit trail through CloudTrail integration

3. **Cost Optimization**:
   - Intelligent tiering for automatic cost savings
   - Lifecycle policies for storage class transitions
   - Expiration rules for old data
   - Abort incomplete multipart uploads

4. **Reliability**:
   - Cross-region replication (optional)
   - Versioning for data recovery
   - Multiple availability zones (S3 default)

5. **Operational Excellence**:
   - Comprehensive tagging strategy
   - Clear naming conventions
   - Detailed outputs for integration
   - Documentation and examples
