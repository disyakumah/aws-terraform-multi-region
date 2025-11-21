# Incident Response & Investigation

## Overview
Comprehensive incident response procedures using AWS Detective, Systems Manager, and automated remediation.

## Incident Response Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    1. DETECTION                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │  GuardDuty  │  │Security Hub │  │ CloudWatch  │           │
│  │   Finding   │  │   Alert     │  │   Alarm     │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    2. INVESTIGATION                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │   Detective │  │  CloudTrail │  │  VPC Flow   │           │
│  │   Analysis  │  │    Logs     │  │    Logs     │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3. CONTAINMENT                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │   Isolate   │  │   Revoke    │  │   Snapshot  │           │
│  │  Instance   │  │Credentials  │  │   Evidence  │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    4. ERADICATION                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │  Terminate  │  │   Patch     │  │   Update    │           │
│  │  Resources  │  │  Systems    │  │   Rules     │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    5. RECOVERY                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │   Restore   │  │   Monitor   │  │  Document   │           │
│  │  Services   │  │   Systems   │  │  Lessons    │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: AWS Detective Setup

### 1.1 Enable Detective

```bash
# Enable Detective
aws detective create-graph

# Get graph ARN
GRAPH_ARN=$(aws detective list-graphs --query 'GraphList[0].Arn' --output text)

# Invite member accounts (if using Organizations)
aws detective create-members \
  --graph-arn $GRAPH_ARN \
  --accounts '[
    {
      "AccountId": "MEMBER-ACCOUNT-ID",
      "EmailAddress": "security@example.com"
    }
  ]'
```

### 1.2 Investigate GuardDuty Finding

```bash
# Get GuardDuty findings
aws guardduty list-findings \
  --detector-id $DETECTOR_ID \
  --finding-criteria '{
    "Criterion": {
      "severity": {
        "Gte": 7
      }
    }
  }'

# Get finding details
aws guardduty get-findings \
  --detector-id $DETECTOR_ID \
  --finding-ids FINDING-ID

# Use Detective to investigate
# Navigate to Detective console and search for:
# - IP address from finding
# - Instance ID
# - IAM principal
# - Time range of suspicious activity
```

## Step 2: Incident Response Playbooks

### 2.1 Compromised IAM Credentials

```bash
#!/bin/bash
# Playbook: Compromised IAM Credentials

# 1. Identify the compromised user
COMPROMISED_USER="username"

# 2. Disable access keys
aws iam list-access-keys --user-name $COMPROMISED_USER | \
  jq -r '.AccessKeyMetadata[].AccessKeyId' | \
  while read key; do
    aws iam update-access-key \
      --user-name $COMPROMISED_USER \
      --access-key-id $key \
      --status Inactive
  done

# 3. Attach deny-all policy
aws iam put-user-policy \
  --user-name $COMPROMISED_USER \
  --policy-name DenyAll \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Deny",
        "Action": "*",
        "Resource": "*"
      }
    ]
  }'

# 4. Revoke all sessions
aws iam update-user \
  --user-name $COMPROMISED_USER \
  --permissions-boundary arn:aws:iam::aws:policy/AWSDenyAll

# 5. Review CloudTrail for unauthorized actions
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=$COMPROMISED_USER \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 50

# 6. Create new credentials (after investigation)
# aws iam create-access-key --user-name $COMPROMISED_USER

# 7. Notify security team
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts \
  --subject "SECURITY INCIDENT: Compromised IAM Credentials" \
  --message "User $COMPROMISED_USER credentials have been compromised and disabled."
```

### 2.2 Compromised EC2 Instance

```bash
#!/bin/bash
# Playbook: Compromised EC2 Instance

INSTANCE_ID="i-xxxxx"

# 1. Create forensic snapshot
VOLUME_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Forensic snapshot - $(date)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Purpose,Value=Forensics},{Key=Incident,Value=INCIDENT-ID}]' \
  --query 'SnapshotId' \
  --output text)

echo "Forensic snapshot created: $SNAPSHOT_ID"

# 2. Isolate instance (change security group)
aws ec2 create-security-group \
  --group-name quarantine-sg \
  --description "Quarantine security group - no ingress/egress" \
  --vpc-id vpc-xxxxx

QUARANTINE_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=quarantine-sg \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

aws ec2 modify-instance-attribute \
  --instance-id $INSTANCE_ID \
  --groups $QUARANTINE_SG

# 3. Tag instance
aws ec2 create-tags \
  --resources $INSTANCE_ID \
  --tags Key=Status,Value=Quarantined Key=Incident,Value=INCIDENT-ID

# 4. Disable instance metadata (prevent credential theft)
aws ec2 modify-instance-metadata-options \
  --instance-id $INSTANCE_ID \
  --http-tokens required \
  --http-endpoint disabled

# 5. Collect memory dump (if needed)
# Use Systems Manager to run memory collection script

# 6. Review CloudTrail for instance activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$INSTANCE_ID \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S)

# 7. Notify security team
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts \
  --subject "SECURITY INCIDENT: Compromised EC2 Instance" \
  --message "Instance $INSTANCE_ID has been quarantined. Snapshot: $SNAPSHOT_ID"
```

### 2.3 Unauthorized S3 Access

```bash
#!/bin/bash
# Playbook: Unauthorized S3 Access

BUCKET_NAME="my-secure-bucket"

# 1. Block all public access immediately
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
    IgnorePublicAcls=true,\
    BlockPublicPolicy=true,\
    RestrictPublicBuckets=true

# 2. Review bucket policy
aws s3api get-bucket-policy --bucket $BUCKET_NAME

# 3. Review bucket ACL
aws s3api get-bucket-acl --bucket $BUCKET_NAME

# 4. Check for public objects
aws s3api list-objects-v2 \
  --bucket $BUCKET_NAME \
  --query 'Contents[?StorageClass==`STANDARD`].[Key]' \
  --output text | \
  while read object; do
    ACL=$(aws s3api get-object-acl --bucket $BUCKET_NAME --key "$object")
    echo "$object: $ACL"
  done

# 5. Review S3 access logs
aws s3api get-bucket-logging --bucket $BUCKET_NAME

# 6. Enable MFA Delete
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::ACCOUNT-ID:mfa/root-account-mfa-device XXXXXX"

# 7. Review CloudTrail for S3 API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$BUCKET_NAME \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S)

# 8. Notify security team
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts \
  --subject "SECURITY INCIDENT: Unauthorized S3 Access" \
  --message "Bucket $BUCKET_NAME has been secured. Review access logs."
```

### 2.4 Cryptocurrency Mining Detection

```bash
#!/bin/bash
# Playbook: Cryptocurrency Mining

INSTANCE_ID="i-xxxxx"

# 1. Immediately stop instance
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# 2. Create forensic snapshot
VOLUME_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Crypto mining forensics - $(date)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Purpose,Value=CryptoMining}]'

# 3. Review network connections
aws ec2 describe-flow-logs \
  --filter Name=resource-id,Values=$INSTANCE_ID

# 4. Check for unusual outbound traffic
# Review VPC Flow Logs for connections to known mining pools

# 5. Terminate instance (after investigation)
# aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# 6. Review IAM for unauthorized instance launches
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S)

# 7. Notify security team
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts \
  --subject "SECURITY INCIDENT: Cryptocurrency Mining Detected" \
  --message "Instance $INSTANCE_ID stopped due to crypto mining activity."
```

## Step 3: Automated Remediation

### 3.1 Lambda Function for Auto-Remediation

```python
# lambda_function.py
import boto3
import json

ec2 = boto3.client('ec2')
iam = boto3.client('iam')
sns = boto3.client('sns')

def lambda_handler(event, context):
    """
    Automated remediation for Security Hub findings
    """
    
    # Parse Security Hub finding
    finding = event['detail']['findings'][0]
    finding_type = finding['Types'][0]
    severity = finding['Severity']['Label']
    
    # Route to appropriate remediation
    if 'UnauthorizedAccess' in finding_type:
        remediate_unauthorized_access(finding)
    elif 'S3' in finding_type and 'PublicAccess' in finding_type:
        remediate_public_s3(finding)
    elif 'SecurityGroup' in finding_type:
        remediate_security_group(finding)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Remediation completed')
    }

def remediate_unauthorized_access(finding):
    """Remediate unauthorized access attempts"""
    
    # Extract IAM user from finding
    user_name = finding['Resources'][0]['Details']['AwsIamUser']['UserName']
    
    # Disable access keys
    access_keys = iam.list_access_keys(UserName=user_name)
    for key in access_keys['AccessKeyMetadata']:
        iam.update_access_key(
            UserName=user_name,
            AccessKeyId=key['AccessKeyId'],
            Status='Inactive'
        )
    
    # Notify security team
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts',
        Subject='Auto-Remediation: IAM User Disabled',
        Message=f'User {user_name} has been disabled due to unauthorized access attempts.'
    )

def remediate_public_s3(finding):
    """Remediate public S3 bucket"""
    
    s3 = boto3.client('s3')
    bucket_name = finding['Resources'][0]['Id'].split(':')[-1]
    
    # Block public access
    s3.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            'BlockPublicAcls': True,
            'IgnorePublicAcls': True,
            'BlockPublicPolicy': True,
            'RestrictPublicBuckets': True
        }
    )
    
    # Notify security team
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts',
        Subject='Auto-Remediation: S3 Bucket Secured',
        Message=f'Bucket {bucket_name} public access has been blocked.'
    )

def remediate_security_group(finding):
    """Remediate overly permissive security group"""
    
    sg_id = finding['Resources'][0]['Id'].split('/')[-1]
    
    # Get security group rules
    sg = ec2.describe_security_groups(GroupIds=[sg_id])
    
    # Remove 0.0.0.0/0 ingress rules
    for rule in sg['SecurityGroups'][0]['IpPermissions']:
        for ip_range in rule.get('IpRanges', []):
            if ip_range['CidrIp'] == '0.0.0.0/0':
                ec2.revoke_security_group_ingress(
                    GroupId=sg_id,
                    IpPermissions=[rule]
                )
    
    # Notify security team
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:ACCOUNT-ID:security-alerts',
        Subject='Auto-Remediation: Security Group Updated',
        Message=f'Security group {sg_id} overly permissive rules removed.'
    )
```

### 3.2 EventBridge Rule for Auto-Remediation

```bash
# Create EventBridge rule
aws events put-rule \
  --name SecurityHubAutoRemediation \
  --event-pattern '{
    "source": ["aws.securityhub"],
    "detail-type": ["Security Hub Findings - Imported"],
    "detail": {
      "findings": {
        "Severity": {
          "Label": ["HIGH", "CRITICAL"]
        },
        "Workflow": {
          "Status": ["NEW"]
        }
      }
    }
  }' \
  --state ENABLED

# Add Lambda target
aws events put-targets \
  --rule SecurityHubAutoRemediation \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT-ID:function:SecurityAutoRemediation"
```

## Step 4: Forensics Collection

### 4.1 Systems Manager for Evidence Collection

```bash
# Create SSM document for forensics
aws ssm create-document \
  --name "CollectForensics" \
  --document-type "Command" \
  --content '{
    "schemaVersion": "2.2",
    "description": "Collect forensic evidence from EC2 instance",
    "mainSteps": [
      {
        "action": "aws:runShellScript",
        "name": "collectEvidence",
        "inputs": {
          "runCommand": [
            "#!/bin/bash",
            "mkdir -p /tmp/forensics",
            "ps aux > /tmp/forensics/processes.txt",
            "netstat -tulpn > /tmp/forensics/network.txt",
            "last -f /var/log/wtmp > /tmp/forensics/logins.txt",
            "find /tmp -type f -mtime -1 > /tmp/forensics/recent_files.txt",
            "tar -czf /tmp/forensics-$(date +%Y%m%d-%H%M%S).tar.gz /tmp/forensics/",
            "aws s3 cp /tmp/forensics-*.tar.gz s3://forensics-bucket-ACCOUNT-ID/"
          ]
        }
      }
    ]
  }'

# Run forensics collection
aws ssm send-command \
  --document-name "CollectForensics" \
  --instance-ids "i-xxxxx" \
  --comment "Forensics collection for incident INCIDENT-ID"
```

### 4.2 Memory Dump Collection

```bash
# Install LiME (Linux Memory Extractor) via SSM
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --instance-ids "i-xxxxx" \
  --parameters 'commands=[
    "sudo apt-get update",
    "sudo apt-get install -y build-essential linux-headers-$(uname -r)",
    "git clone https://github.com/504ensicsLabs/LiME",
    "cd LiME/src",
    "make",
    "sudo insmod lime-$(uname -r).ko path=/tmp/memory.lime format=lime",
    "aws s3 cp /tmp/memory.lime s3://forensics-bucket-ACCOUNT-ID/"
  ]'
```

## Step 5: Incident Documentation

### 5.1 Incident Report Template

```markdown
# Security Incident Report

## Incident Details
- **Incident ID:** INC-2024-001
- **Date/Time Detected:** 2024-01-15 14:30 UTC
- **Severity:** HIGH
- **Status:** RESOLVED

## Summary
Brief description of the incident.

## Timeline
- 14:30 UTC - GuardDuty alert triggered
- 14:35 UTC - Investigation started
- 14:45 UTC - Compromised instance isolated
- 15:00 UTC - Forensic snapshot created
- 15:30 UTC - Instance terminated
- 16:00 UTC - Root cause identified

## Affected Resources
- EC2 Instance: i-xxxxx
- IAM User: compromised-user
- S3 Bucket: affected-bucket

## Root Cause
Detailed analysis of how the incident occurred.

## Actions Taken
1. Isolated compromised instance
2. Created forensic snapshots
3. Disabled IAM credentials
4. Reviewed CloudTrail logs
5. Terminated malicious resources

## Lessons Learned
- What went well
- What could be improved
- Preventive measures

## Recommendations
1. Implement additional monitoring
2. Update security group rules
3. Enhance IAM policies
4. Conduct security training
```

## Security Best Practices

### ✅ DO
- Enable AWS Detective
- Create incident response playbooks
- Automate remediation where possible
- Collect forensic evidence before termination
- Document all incidents
- Conduct post-incident reviews
- Test incident response procedures
- Maintain incident response team contacts

### ❌ DON'T
- Don't terminate resources without forensics
- Don't ignore low severity findings
- Don't skip documentation
- Don't delay containment
- Don't forget to notify stakeholders
- Don't reuse compromised credentials
- Don't skip root cause analysis

## Terraform Implementation

```hcl
# Detective
resource "aws_detective_graph" "main" {}

# Auto-remediation Lambda
resource "aws_lambda_function" "auto_remediation" {
  filename      = "lambda_function.zip"
  function_name = "SecurityAutoRemediation"
  role          = aws_iam_role.lambda_remediation.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }
}

# EventBridge rule
resource "aws_cloudwatch_event_rule" "security_hub" {
  name        = "SecurityHubAutoRemediation"
  description = "Trigger auto-remediation for Security Hub findings"
  
  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.security_hub.name
  target_id = "SecurityAutoRemediation"
  arn       = aws_lambda_function.auto_remediation.arn
}
```

## Validation Checklist

- [ ] AWS Detective enabled
- [ ] Incident response playbooks created
- [ ] Auto-remediation Lambda deployed
- [ ] EventBridge rules configured
- [ ] Forensics collection procedures tested
- [ ] SNS notifications configured
- [ ] Incident documentation template ready
- [ ] Security team contacts updated
- [ ] Runbooks tested
- [ ] Post-incident review process defined

**Next:** [Compliance & Monitoring](07-compliance-monitoring.md)
