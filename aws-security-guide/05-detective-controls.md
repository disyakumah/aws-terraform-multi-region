# Detective Controls - Monitoring & Threat Detection

## Overview
Implement comprehensive detective controls using CloudTrail, GuardDuty, Config, and Security Hub.

## Detective Controls Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOGGING LAYER                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │ CloudTrail  │  │  VPC Flow   │  │   S3 Access │           │
│  │   Logs      │  │    Logs     │  │    Logs     │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    THREAT DETECTION                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │  GuardDuty  │  │   Config    │  │  Macie      │           │
│  │   ML-based  │  │ Compliance  │  │   Data      │           │
│  │  Detection  │  │  Monitoring │  │ Discovery   │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CENTRALIZED DASHBOARD                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              AWS Security Hub                           │   │
│  │  • Aggregated findings                                  │   │
│  │  • Compliance scores                                    │   │
│  │  • Automated remediation                                │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: CloudTrail Setup

### 1.1 Create Organization Trail

```bash
# Create S3 bucket for CloudTrail logs
aws s3api create-bucket \
  --bucket cloudtrail-logs-ACCOUNT-ID \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket cloudtrail-logs-ACCOUNT-ID \
  --versioning-configuration Status=Enabled

# Apply bucket policy
aws s3api put-bucket-policy \
  --bucket cloudtrail-logs-ACCOUNT-ID \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AWSCloudTrailAclCheck",
        "Effect": "Allow",
        "Principal": {
          "Service": "cloudtrail.amazonaws.com"
        },
        "Action": "s3:GetBucketAcl",
        "Resource": "arn:aws:s3:::cloudtrail-logs-ACCOUNT-ID"
      },
      {
        "Sid": "AWSCloudTrailWrite",
        "Effect": "Allow",
        "Principal": {
          "Service": "cloudtrail.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::cloudtrail-logs-ACCOUNT-ID/*",
        "Condition": {
          "StringEquals": {
            "s3:x-amz-acl": "bucket-owner-full-control"
          }
        }
      }
    ]
  }'

# Create CloudTrail
aws cloudtrail create-trail \
  --name organization-trail \
  --s3-bucket-name cloudtrail-logs-ACCOUNT-ID \
  --is-multi-region-trail \
  --is-organization-trail \
  --enable-log-file-validation \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID

# Start logging
aws cloudtrail start-logging \
  --name organization-trail

# Enable CloudWatch Logs integration
aws cloudtrail update-trail \
  --name organization-trail \
  --cloud-watch-logs-log-group-arn arn:aws:logs:us-east-1:ACCOUNT-ID:log-group:/aws/cloudtrail/organization \
  --cloud-watch-logs-role-arn arn:aws:iam::ACCOUNT-ID:role/CloudTrailCloudWatchLogsRole
```

### 1.2 Configure Event Selectors

```bash
# Enable data events for S3
aws cloudtrail put-event-selectors \
  --trail-name organization-trail \
  --event-selectors '[
    {
      "ReadWriteType": "All",
      "IncludeManagementEvents": true,
      "DataResources": [
        {
          "Type": "AWS::S3::Object",
          "Values": ["arn:aws:s3:::*/"]
        }
      ]
    }
  ]'

# Enable Insights
aws cloudtrail put-insight-selectors \
  --trail-name organization-trail \
  --insight-selectors '[
    {
      "InsightType": "ApiCallRateInsight"
    }
  ]'
```

### 1.3 Create CloudWatch Alarms

```bash
# Create metric filter for root account usage
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name RootAccountUsage \
  --filter-pattern '{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }' \
  --metric-transformations \
    metricName=RootAccountUsageCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# Create alarm
aws cloudwatch put-metric-alarm \
  --alarm-name RootAccountUsage \
  --alarm-description "Alert on root account usage" \
  --metric-name RootAccountUsageCount \
  --namespace CloudTrailMetrics \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts

# Unauthorized API calls
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name UnauthorizedAPICalls \
  --filter-pattern '{ ($.errorCode = "*UnauthorizedOperation") || ($.errorCode = "AccessDenied*") }' \
  --metric-transformations \
    metricName=UnauthorizedAPICallsCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# Console sign-in failures
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name ConsoleSignInFailures \
  --filter-pattern '{ ($.eventName = ConsoleLogin) && ($.errorMessage = "Failed authentication") }' \
  --metric-transformations \
    metricName=ConsoleSignInFailureCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1
```

## Step 2: GuardDuty Setup

### 2.1 Enable GuardDuty

```bash
# Enable GuardDuty
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES

# Get detector ID
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)

# Enable S3 Protection
aws guardduty update-detector \
  --detector-id $DETECTOR_ID \
  --data-sources '{
    "S3Logs": {
      "Enable": true
    }
  }'

# Enable EKS Protection (if using EKS)
aws guardduty update-detector \
  --detector-id $DETECTOR_ID \
  --data-sources '{
    "Kubernetes": {
      "AuditLogs": {
        "Enable": true
      }
    }
  }'

# Enable Malware Protection
aws guardduty update-detector \
  --detector-id $DETECTOR_ID \
  --data-sources '{
    "MalwareProtection": {
      "ScanEc2InstanceWithFindings": {
        "EbsVolumes": {
          "Enable": true
        }
      }
    }
  }'
```

### 2.2 Configure GuardDuty Findings Export

```bash
# Create S3 bucket for findings
aws s3api create-bucket \
  --bucket guardduty-findings-ACCOUNT-ID \
  --region us-east-1

# Configure findings export
aws guardduty create-publishing-destination \
  --detector-id $DETECTOR_ID \
  --destination-type S3 \
  --destination-properties '{
    "DestinationArn": "arn:aws:s3:::guardduty-findings-ACCOUNT-ID",
    "KmsKeyArn": "arn:aws:kms:us-east-1:ACCOUNT-ID:key/KEY-ID"
  }'
```

### 2.3 Create GuardDuty Filters

```bash
# Create filter for high severity findings
aws guardduty create-filter \
  --detector-id $DETECTOR_ID \
  --name HighSeverityFindings \
  --finding-criteria '{
    "Criterion": {
      "severity": {
        "Gte": 7
      }
    }
  }' \
  --action ARCHIVE

# Create filter for specific threat types
aws guardduty create-filter \
  --detector-id $DETECTOR_ID \
  --name CryptoMiningFindings \
  --finding-criteria '{
    "Criterion": {
      "type": {
        "Eq": ["CryptoCurrency:EC2/BitcoinTool.B!DNS"]
      }
    }
  }' \
  --action NOOP
```

## Step 3: AWS Config Setup

### 3.1 Enable AWS Config

```bash
# Create S3 bucket for Config
aws s3api create-bucket \
  --bucket config-logs-ACCOUNT-ID \
  --region us-east-1

# Create Config recorder
aws configservice put-configuration-recorder \
  --configuration-recorder '{
    "name": "default",
    "roleARN": "arn:aws:iam::ACCOUNT-ID:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig",
    "recordingGroup": {
      "allSupported": true,
      "includeGlobalResourceTypes": true
    }
  }'

# Create delivery channel
aws configservice put-delivery-channel \
  --delivery-channel '{
    "name": "default",
    "s3BucketName": "config-logs-ACCOUNT-ID",
    "configSnapshotDeliveryProperties": {
      "deliveryFrequency": "TwentyFour_Hours"
    }
  }'

# Start Config recorder
aws configservice start-configuration-recorder \
  --configuration-recorder-name default
```

### 3.2 Deploy Config Rules

```bash
# S3 bucket public read prohibited
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "s3-bucket-public-read-prohibited",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    }
  }'

# S3 bucket encryption enabled
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "s3-bucket-server-side-encryption-enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    }
  }'

# RDS encryption enabled
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "rds-storage-encrypted",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "RDS_STORAGE_ENCRYPTED"
    }
  }'

# EBS encryption enabled
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "ec2-ebs-encryption-by-default",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "EC2_EBS_ENCRYPTION_BY_DEFAULT"
    }
  }'

# IAM password policy
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "iam-password-policy",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "IAM_PASSWORD_POLICY"
    },
    "InputParameters": "{\"RequireUppercaseCharacters\":\"true\",\"RequireLowercaseCharacters\":\"true\",\"RequireSymbols\":\"true\",\"RequireNumbers\":\"true\",\"MinimumPasswordLength\":\"14\",\"PasswordReusePrevention\":\"24\",\"MaxPasswordAge\":\"90\"}"
  }'

# MFA enabled for root
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "root-account-mfa-enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "ROOT_ACCOUNT_MFA_ENABLED"
    }
  }'

# CloudTrail enabled
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "cloudtrail-enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "CLOUD_TRAIL_ENABLED"
    }
  }'

# Security group no unrestricted SSH
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "restricted-ssh",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "INCOMING_SSH_DISABLED"
    }
  }'

# VPC flow logs enabled
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "vpc-flow-logs-enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "VPC_FLOW_LOGS_ENABLED"
    }
  }'
```

### 3.3 Create Config Aggregator

```bash
# Create aggregator for organization
aws configservice put-configuration-aggregator \
  --configuration-aggregator-name organization-aggregator \
  --organization-aggregation-source '{
    "RoleArn": "arn:aws:iam::ACCOUNT-ID:role/aws-service-role/organizations.amazonaws.com/AWSServiceRoleForOrganizations",
    "AllAwsRegions": true
  }'
```

## Step 4: Security Hub Setup

### 4.1 Enable Security Hub

```bash
# Enable Security Hub
aws securityhub enable-security-hub

# Enable security standards
# CIS AWS Foundations Benchmark
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.4.0"
    }
  ]'

# AWS Foundational Security Best Practices
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"
    }
  ]'

# PCI DSS (if applicable)
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:us-east-1::standards/pci-dss/v/3.2.1"
    }
  ]'
```

### 4.2 Enable Product Integrations

```bash
# Enable GuardDuty integration
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/guardduty

# Enable Config integration
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/config

# Enable IAM Access Analyzer
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/access-analyzer

# Enable Macie
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/macie

# Enable Inspector
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/inspector
```

### 4.3 Configure Custom Actions

```bash
# Create custom action for automated remediation
aws securityhub create-action-target \
  --name "Send to Lambda for Remediation" \
  --description "Trigger Lambda function for automated remediation" \
  --id SendToLambdaRemediation
```

## Step 5: Amazon Macie Setup

### 5.1 Enable Macie

```bash
# Enable Macie
aws macie2 enable-macie

# Create classification job
aws macie2 create-classification-job \
  --job-type SCHEDULED \
  --name "Daily S3 Scan" \
  --s3-job-definition '{
    "bucketDefinitions": [
      {
        "accountId": "ACCOUNT-ID",
        "buckets": ["my-secure-bucket"]
      }
    ]
  }' \
  --schedule-frequency '{
    "dailySchedule": {}
  }'
```

### 5.2 Create Custom Data Identifiers

```bash
# Create custom identifier for employee IDs
aws macie2 create-custom-data-identifier \
  --name "EmployeeID" \
  --regex "EMP-[0-9]{6}" \
  --description "Company employee ID pattern"

# Create custom identifier for internal API keys
aws macie2 create-custom-data-identifier \
  --name "InternalAPIKey" \
  --regex "INTERNAL-[A-Z0-9]{32}" \
  --description "Internal API key pattern"
```

## Step 6: IAM Access Analyzer

### 6.1 Enable Access Analyzer

```bash
# Create analyzer
aws accessanalyzer create-analyzer \
  --analyzer-name organization-analyzer \
  --type ORGANIZATION

# List findings
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:us-east-1:ACCOUNT-ID:analyzer/organization-analyzer
```

## Security Best Practices

### ✅ DO
- Enable CloudTrail in all regions
- Enable log file validation
- Enable GuardDuty in all accounts
- Deploy AWS Config rules
- Enable Security Hub standards
- Configure automated alerts
- Export findings to S3
- Enable Macie for sensitive data
- Use IAM Access Analyzer
- Monitor CloudWatch metrics

### ❌ DON'T
- Don't disable CloudTrail
- Don't ignore GuardDuty findings
- Don't skip Config rule remediation
- Don't disable Security Hub
- Don't ignore high severity findings
- Don't store logs without encryption
- Don't skip log analysis
- Don't ignore compliance violations

## Terraform Implementation

```hcl
# CloudTrail
resource "aws_cloudtrail" "organization" {
  name                          = "organization-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail        = true
  is_organization_trail        = true
  enable_log_file_validation   = true
  kms_key_id                   = aws_kms_key.cloudtrail.arn
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }
  }
  
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true
  
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
}

# Security Hub
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

# Config
resource "aws_config_configuration_recorder" "main" {
  name     = "default"
  role_arn = aws_iam_role.config.arn
  
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config.bucket
}
```

## Validation Checklist

- [ ] CloudTrail enabled in all regions
- [ ] Log file validation enabled
- [ ] GuardDuty enabled
- [ ] S3 Protection enabled in GuardDuty
- [ ] AWS Config enabled
- [ ] Config rules deployed
- [ ] Security Hub enabled
- [ ] Security standards enabled
- [ ] Product integrations configured
- [ ] Macie enabled for sensitive data
- [ ] IAM Access Analyzer enabled
- [ ] CloudWatch alarms configured
- [ ] SNS notifications set up

**Next:** [Incident Response & Investigation](06-incident-response.md)
