# Data Protection & Encryption

## Overview
Comprehensive guide to implementing encryption at rest and in transit across all AWS services.

## Encryption Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENCRYPTION AT REST                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │     S3      │  │     RDS     │  │     EBS     │           │
│  │   AES-256   │  │   AES-256   │  │   AES-256   │           │
│  │  KMS Keys   │  │  KMS Keys   │  │  KMS Keys   │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ENCRYPTION IN TRANSIT                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │  TLS 1.3    │  │   HTTPS     │  │   VPN/DX    │           │
│  │  ALB/NLB    │  │ CloudFront  │  │  Encrypted  │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: AWS KMS Setup

### 1.1 Create Customer Managed Keys (CMK)

```bash
# Create KMS key for S3
aws kms create-key \
  --description "S3 encryption key for production" \
  --key-policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "Enable IAM User Permissions",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::ACCOUNT-ID:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Sid": "Allow S3 to use the key",
        "Effect": "Allow",
        "Principal": {
          "Service": "s3.amazonaws.com"
        },
        "Action": [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        "Resource": "*"
      }
    ]
  }' \
  --tags TagKey=Environment,TagValue=production TagKey=Service,TagValue=S3

# Create alias for easier reference
aws kms create-alias \
  --alias-name alias/s3-production \
  --target-key-id KEY-ID

# Enable automatic key rotation
aws kms enable-key-rotation \
  --key-id KEY-ID
```

### 1.2 Create Separate Keys for Each Service

```bash
# RDS encryption key
aws kms create-key \
  --description "RDS encryption key for production" \
  --tags TagKey=Service,TagValue=RDS

aws kms create-alias \
  --alias-name alias/rds-production \
  --target-key-id KEY-ID

# EBS encryption key
aws kms create-key \
  --description "EBS encryption key for production" \
  --tags TagKey=Service,TagValue=EBS

aws kms create-alias \
  --alias-name alias/ebs-production \
  --target-key-id KEY-ID

# Secrets Manager encryption key
aws kms create-key \
  --description "Secrets Manager encryption key" \
  --tags TagKey=Service,TagValue=SecretsManager

aws kms create-alias \
  --alias-name alias/secrets-production \
  --target-key-id KEY-ID
```

## Step 2: S3 Encryption

### 2.1 Enable Default Encryption

```bash
# Enable default encryption with KMS
aws s3api put-bucket-encryption \
  --bucket my-secure-bucket \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket my-secure-bucket \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
    IgnorePublicAcls=true,\
    BlockPublicPolicy=true,\
    RestrictPublicBuckets=true

# Enable versioning for data protection
aws s3api put-bucket-versioning \
  --bucket my-secure-bucket \
  --versioning-configuration Status=Enabled

# Enable MFA Delete (requires root account)
aws s3api put-bucket-versioning \
  --bucket my-secure-bucket \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::ACCOUNT-ID:mfa/root-account-mfa-device XXXXXX"
```

### 2.2 Bucket Policy for Encryption Enforcement

```bash
aws s3api put-bucket-policy \
  --bucket my-secure-bucket \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyUnencryptedObjectUploads",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::my-secure-bucket/*",
        "Condition": {
          "StringNotEquals": {
            "s3:x-amz-server-side-encryption": "aws:kms"
          }
        }
      },
      {
        "Sid": "DenyInsecureTransport",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::my-secure-bucket",
          "arn:aws:s3:::my-secure-bucket/*"
        ],
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  }'
```

## Step 3: RDS Encryption

### 3.1 Create Encrypted RDS Instance

```bash
# Create encrypted RDS instance
aws rds create-db-instance \
  --db-instance-identifier production-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --master-username admin \
  --master-user-password SECURE-PASSWORD \
  --allocated-storage 100 \
  --storage-encrypted \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --db-subnet-group-name production-db-subnet-group \
  --vpc-security-group-ids sg-xxxxx \
  --enable-cloudwatch-logs-exports '["postgresql"]' \
  --deletion-protection \
  --no-publicly-accessible
```

### 3.2 Enable Automated Backups with Encryption

```bash
# Modify existing instance to enable encryption (requires snapshot restore)
# Step 1: Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier production-db \
  --db-snapshot-identifier production-db-snapshot

# Step 2: Copy snapshot with encryption
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier production-db-snapshot \
  --target-db-snapshot-identifier production-db-encrypted-snapshot \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID

# Step 3: Restore from encrypted snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier production-db-encrypted \
  --db-snapshot-identifier production-db-encrypted-snapshot
```

## Step 4: EBS Encryption

### 4.1 Enable EBS Encryption by Default

```bash
# Enable EBS encryption by default for the region
aws ec2 enable-ebs-encryption-by-default

# Set default KMS key for EBS encryption
aws ec2 modify-ebs-default-kms-key-id \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID

# Verify encryption is enabled
aws ec2 get-ebs-encryption-by-default
```

### 4.2 Create Encrypted EBS Volume

```bash
# Create encrypted EBS volume
aws ec2 create-volume \
  --availability-zone us-east-1a \
  --size 100 \
  --volume-type gp3 \
  --encrypted \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=encrypted-volume}]'
```

### 4.3 Encrypt Existing Unencrypted Volume

```bash
# Step 1: Create snapshot of unencrypted volume
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "Snapshot for encryption"

# Step 2: Copy snapshot with encryption
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-xxxxx \
  --encrypted \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID

# Step 3: Create encrypted volume from snapshot
aws ec2 create-volume \
  --snapshot-id snap-encrypted-xxxxx \
  --availability-zone us-east-1a
```

## Step 5: Secrets Manager

### 5.1 Store Database Credentials

```bash
# Create secret for database credentials
aws secretsmanager create-secret \
  --name production/db/credentials \
  --description "Production database credentials" \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID \
  --secret-string '{
    "username": "admin",
    "password": "SECURE-PASSWORD",
    "engine": "postgres",
    "host": "production-db.xxxxx.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "dbname": "production"
  }'

# Enable automatic rotation
aws secretsmanager rotate-secret \
  --secret-id production/db/credentials \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:ACCOUNT-ID:function:SecretsManagerRotation \
  --rotation-rules AutomaticallyAfterDays=30
```

### 5.2 Store API Keys

```bash
# Create secret for API keys
aws secretsmanager create-secret \
  --name production/api/keys \
  --description "Production API keys" \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID \
  --secret-string '{
    "stripe_api_key": "sk_live_xxxxx",
    "sendgrid_api_key": "SG.xxxxx"
  }'
```

## Step 6: Encryption in Transit

### 6.1 ALB with TLS 1.3

```bash
# Create ALB with HTTPS listener
aws elbv2 create-load-balancer \
  --name production-alb \
  --subnets subnet-xxxxx subnet-yyyyy \
  --security-groups sg-xxxxx \
  --scheme internet-facing \
  --type application

# Create HTTPS listener with TLS 1.3
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:ACCOUNT-ID:loadbalancer/app/production-alb/xxxxx \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:us-east-1:ACCOUNT-ID:certificate/xxxxx \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:ACCOUNT-ID:targetgroup/xxxxx

# Create HTTP to HTTPS redirect
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:ACCOUNT-ID:loadbalancer/app/production-alb/xxxxx \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'
```

### 6.2 CloudFront with TLS

```bash
# Create CloudFront distribution with TLS
aws cloudfront create-distribution \
  --distribution-config '{
    "CallerReference": "production-distribution",
    "Comment": "Production CDN",
    "Enabled": true,
    "Origins": {
      "Quantity": 1,
      "Items": [
        {
          "Id": "S3-production-bucket",
          "DomainName": "my-secure-bucket.s3.amazonaws.com",
          "S3OriginConfig": {
            "OriginAccessIdentity": "origin-access-identity/cloudfront/xxxxx"
          }
        }
      ]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "S3-production-bucket",
      "ViewerProtocolPolicy": "redirect-to-https",
      "MinTTL": 0,
      "ForwardedValues": {
        "QueryString": false,
        "Cookies": {"Forward": "none"}
      }
    },
    "ViewerCertificate": {
      "ACMCertificateArn": "arn:aws:acm:us-east-1:ACCOUNT-ID:certificate/xxxxx",
      "SSLSupportMethod": "sni-only",
      "MinimumProtocolVersion": "TLSv1.2_2021"
    }
  }'
```

## Step 7: Certificate Management (ACM)

### 7.1 Request Public Certificate

```bash
# Request certificate from ACM
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names www.example.com api.example.com \
  --validation-method DNS \
  --tags Key=Environment,Value=production

# Describe certificate to get validation records
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:ACCOUNT-ID:certificate/xxxxx
```

### 7.2 Enable Certificate Transparency Logging

```bash
# Certificate transparency is enabled by default for ACM certificates
# Verify certificate is logged
aws acm get-certificate \
  --certificate-arn arn:aws:acm:us-east-1:ACCOUNT-ID:certificate/xxxxx
```

## Security Best Practices

### ✅ DO
- Use AWS KMS for all encryption keys
- Enable automatic key rotation
- Use separate KMS keys for each service
- Enable encryption by default (S3, EBS, RDS)
- Use TLS 1.3 for all connections
- Store secrets in Secrets Manager
- Enable MFA Delete for S3 buckets
- Use ACM for certificate management
- Enforce encryption in transit
- Enable CloudTrail for KMS key usage

### ❌ DON'T
- Don't use AWS managed keys for sensitive data
- Don't store credentials in code or environment variables
- Don't allow unencrypted data uploads
- Don't use TLS 1.0 or 1.1
- Don't share KMS keys across environments
- Don't disable encryption for cost savings
- Don't use self-signed certificates in production
- Don't allow HTTP traffic without HTTPS redirect

## Terraform Implementation

```hcl
# KMS Key
resource "aws_kms_key" "s3" {
  description             = "S3 encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = "production"
    Service     = "S3"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/s3-production"
  target_key_id = aws_kms_key.s3.key_id
}

# S3 Bucket with Encryption
resource "aws_s3_bucket" "secure" {
  bucket = "my-secure-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.secure.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# RDS with Encryption
resource "aws_db_instance" "production" {
  identifier     = "production-db"
  engine         = "postgres"
  instance_class = "db.t3.medium"
  
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
  
  backup_retention_period = 7
  deletion_protection     = true
  
  db_subnet_group_name   = aws_db_subnet_group.production.name
  vpc_security_group_ids = [aws_security_group.database.id]
}
```

## Validation Checklist

- [ ] KMS keys created for each service
- [ ] Automatic key rotation enabled
- [ ] S3 default encryption enabled
- [ ] S3 public access blocked
- [ ] RDS encryption enabled
- [ ] EBS encryption by default enabled
- [ ] Secrets stored in Secrets Manager
- [ ] TLS 1.3 configured on ALB
- [ ] HTTPS enforced on CloudFront
- [ ] ACM certificates configured
- [ ] MFA Delete enabled on critical buckets
- [ ] Encryption in transit enforced

**Next:** [Detective Controls - CloudTrail & GuardDuty](05-detective-controls.md)
