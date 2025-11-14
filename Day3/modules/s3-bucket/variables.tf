# S3 Bucket Module Variables

# Required Variables
variable "bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique and follow S3 naming conventions."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be between 3 and 63 characters, start and end with lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}


# Encryption Variables
variable "enable_encryption" {
  description = "Enable server-side encryption for the bucket"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Type of encryption to use (AES256 or aws:kms)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_type)
    error_message = "Encryption type must be either 'AES256' or 'aws:kms'."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for SSE-KMS encryption (required if encryption_type is aws:kms)"
  type        = string
  default     = null
}

# Versioning Variables
variable "enable_versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for versioned objects"
  type        = bool
  default     = false
}

# Logging Variables
variable "enable_logging" {
  description = "Enable access logging for the bucket"
  type        = bool
  default     = false
}

variable "logging_bucket_name" {
  description = "Name of the bucket to store access logs (required if enable_logging is true)"
  type        = string
  default     = null
}

# Lifecycle Variables
variable "enable_lifecycle" {
  description = "Enable lifecycle policies for the bucket"
  type        = bool
  default     = true
}

variable "lifecycle_intelligent_tiering_days" {
  description = "Number of days before transitioning objects to Intelligent-Tiering (0 to disable)"
  type        = number
  default     = 30
}

variable "lifecycle_glacier_days" {
  description = "Number of days before transitioning objects to Glacier (0 to disable)"
  type        = number
  default     = 90
}

variable "lifecycle_deep_archive_days" {
  description = "Number of days before transitioning objects to Deep Archive (0 to disable)"
  type        = number
  default     = 180
}

variable "lifecycle_noncurrent_expiration_days" {
  description = "Number of days before expiring non-current versions (0 to disable)"
  type        = number
  default     = 365
}

# Replication Variables
variable "enable_replication" {
  description = "Enable cross-region replication for the bucket"
  type        = bool
  default     = false
}

variable "replication_destination_bucket" {
  description = "ARN of the destination bucket for replication (required if enable_replication is true)"
  type        = string
  default     = null
}

variable "replication_destination_region" {
  description = "AWS region of the destination bucket for replication"
  type        = string
  default     = null
}

# Policy Variables
variable "allowed_principals" {
  description = "List of IAM principal ARNs allowed to access the bucket"
  type        = list(string)
  default     = []
}

variable "allowed_actions" {
  description = "List of S3 actions allowed for the specified principals"
  type        = list(string)
  default     = ["s3:GetObject", "s3:ListBucket"]
}

# General Variables
variable "force_destroy" {
  description = "Allow deletion of non-empty bucket (use with caution)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
