# Compliance & Continuous Monitoring

## Overview
Implement continuous compliance monitoring, security metrics, and reporting for AWS environments.

## Compliance Framework

```
┌─────────────────────────────────────────────────────────────────┐
│                   COMPLIANCE STANDARDS                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │     CIS     │  │   PCI DSS   │  │    HIPAA    │           │
│  │ Foundations │  │             │  │             │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   AUTOMATED CHECKS                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │   Config    │  │Security Hub │  │   Custom    │           │
│  │    Rules    │  │  Standards  │  │   Lambda    │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   REPORTING & METRICS                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │ CloudWatch  │  │  QuickSight │  │     SNS     │           │
│  │ Dashboards  │  │   Reports   │  │   Alerts    │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: CIS AWS Foundations Benchmark

### 1.1 Identity and Access Management

```bash
# 1.1 - Maintain current contact details
aws account put-contact-information \
  --contact-information '{
    "FullName": "Security Team",
    "PhoneNumber": "+1-555-0100",
    "EmailAddress": "security@example.com"
  }'

# 1.2 - Security contact information
aws account put-alternate-contact \
  --alternate-contact-type SECURITY \
  --email-address security@example.com \
  --name "Security Team" \
  --phone-number "+1-555-0100" \
  --title "Security Contact"

# 1.3 - Ensure security questions are registered
# (Must be done via AWS Console)

# 1.4 - Ensure no root account access key exists
aws iam get-account-summary | jq '.SummaryMap.AccountAccessKeysPresent'

# 1.5 - Ensure MFA is enabled for root account
aws iam get-account-summary | jq '.SummaryMap.AccountMFAEnabled'

# 1.6 - Ensure hardware MFA is enabled for root
# (Verify via AWS Console)

# 1.7 - Eliminate use of root user for administrative tasks
# Create CloudWatch alarm for root usage (already covered in detective controls)

# 1.8 - Ensure IAM password policy requires minimum length of 14
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --allow-users-to-change-password \
  --max-password-age 90 \
  --password-reuse-prevention 24 \
  --hard-expiry

# 1.9 - Ensure IAM password policy prevents password reuse
# (Covered in 1.8)

# 1.10 - Ensure multi-factor authentication (MFA) is enabled for all IAM users
# Script to check MFA status
aws iam list-users --query 'Users[*].UserName' --output text | \
  while read user; do
    mfa=$(aws iam list-mfa-devices --user-name $user --query 'MFADevices' --output text)
    if [ -z "$mfa" ]; then
      echo "WARNING: User $user does not have MFA enabled"
    fi
  done

# 1.11 - Do not setup access keys during initial user setup
# (Policy enforcement via IAM)

# 1.12 - Ensure credentials unused for 45 days are disabled
# Script to disable old credentials
aws iam generate-credential-report
sleep 10
aws iam get-credential-report --query 'Content' --output text | base64 -d > /tmp/credentials.csv

# Parse and disable old keys (Python script recommended)

# 1.13 - Ensure there is only one active access key per IAM user
aws iam list-users --query 'Users[*].UserName' --output text | \
  while read user; do
    key_count=$(aws iam list-access-keys --user-name $user --query 'length(AccessKeyMetadata)')
    if [ $key_count -gt 1 ]; then
      echo "WARNING: User $user has $key_count access keys"
    fi
  done

# 1.14 - Ensure access keys are rotated every 90 days
# (Automated via Lambda function)

# 1.15 - Ensure IAM Users Receive Permissions Only Through Groups
# (Policy enforcement)

# 1.16 - Ensure IAM policies that allow full "*:*" are not attached
aws iam list-policies --scope Local --query 'Policies[*].Arn' --output text | \
  while read policy; do
    doc=$(aws iam get-policy-version \
      --policy-arn $policy \
      --version-id $(aws iam get-policy --policy-arn $policy --query 'Policy.DefaultVersionId' --output text))
    echo "$doc" | jq -r '.PolicyVersion.Document' | grep -q '"Action":"*"' && \
      echo "WARNING: Policy $policy allows full access"
  done

# 1.17 - Ensure a support role has been created
aws iam get-role --role-name AWSSupportAccess

# 1.18 - Ensure IAM instance roles are used for AWS resource access
# (Verify via EC2 console)

# 1.19 - Ensure expired SSL/TLS certificates are removed
aws iam list-server-certificates

# 1.20 - Ensure IAM Access analyzer is enabled
aws accessanalyzer list-analyzers

# 1.21 - Ensure IAM users are managed centrally via identity federation or AWS Organizations
# (Organizational policy)
```

### 1.2 Storage (S3)

```bash
# 2.1.1 - Ensure S3 Bucket Policy allows HTTPS requests only
# (Covered in data protection section)

# 2.1.2 - Ensure MFA Delete is enabled on S3 buckets
aws s3api get-bucket-versioning --bucket BUCKET-NAME

# 2.1.3 - Ensure all data in S3 is encrypted at rest
# Script to check all buckets
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  while read bucket; do
    encryption=$(aws s3api get-bucket-encryption --bucket $bucket 2>&1)
    if echo "$encryption" | grep -q "ServerSideEncryptionConfigurationNotFoundError"; then
      echo "WARNING: Bucket $bucket does not have encryption enabled"
    fi
  done

# 2.1.4 - Ensure S3 Bucket Policy is set to deny HTTP requests
# (Covered in data protection section)

# 2.2.1 - Ensure EBS volume encryption is enabled
aws ec2 get-ebs-encryption-by-default

# 2.3.1 - Ensure RDS instances are encrypted
aws rds describe-db-instances \
  --query 'DBInstances[?StorageEncrypted==`false`].[DBInstanceIdentifier]' \
  --output table
```

### 1.3 Logging

```bash
# 3.1 - Ensure CloudTrail is enabled in all regions
aws cloudtrail describe-trails --query 'trailList[?IsMultiRegionTrail==`false`]'

# 3.2 - Ensure CloudTrail log file validation is enabled
aws cloudtrail describe-trails --query 'trailList[?LogFileValidationEnabled==`false`]'

# 3.3 - Ensure S3 bucket used for CloudTrail logs is not publicly accessible
aws s3api get-bucket-acl --bucket CLOUDTRAIL-BUCKET

# 3.4 - Ensure CloudTrail trails are integrated with CloudWatch Logs
aws cloudtrail describe-trails --query 'trailList[?CloudWatchLogsLogGroupArn==null]'

# 3.5 - Ensure AWS Config is enabled in all regions
aws configservice describe-configuration-recorders

# 3.6 - Ensure S3 bucket access logging is enabled
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  while read bucket; do
    logging=$(aws s3api get-bucket-logging --bucket $bucket 2>&1)
    if echo "$logging" | grep -q "LoggingEnabled"; then
      echo "OK: Bucket $bucket has logging enabled"
    else
      echo "WARNING: Bucket $bucket does not have logging enabled"
    fi
  done

# 3.7 - Ensure CloudTrail logs are encrypted at rest using KMS
aws cloudtrail describe-trails --query 'trailList[?KmsKeyId==null]'

# 3.8 - Ensure rotation for customer created CMKs is enabled
aws kms list-keys --query 'Keys[*].KeyId' --output text | \
  while read key; do
    rotation=$(aws kms get-key-rotation-status --key-id $key --query 'KeyRotationEnabled')
    if [ "$rotation" = "false" ]; then
      echo "WARNING: Key $key does not have rotation enabled"
    fi
  done

# 3.9 - Ensure VPC flow logging is enabled in all VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' --output text | \
  while read vpc; do
    flow_logs=$(aws ec2 describe-flow-logs --filter Name=resource-id,Values=$vpc --query 'FlowLogs')
    if [ "$flow_logs" = "[]" ]; then
      echo "WARNING: VPC $vpc does not have flow logs enabled"
    fi
  done
```

### 1.4 Monitoring

```bash
# 4.1 - Ensure unauthorized API calls are monitored
# (Covered in detective controls)

# 4.2 - Ensure management console sign-in without MFA is monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name ConsoleSignInWithoutMFA \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") }' \
  --metric-transformations \
    metricName=ConsoleSignInWithoutMFACount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.3 - Ensure usage of root account is monitored
# (Already covered)

# 4.4 - Ensure IAM policy changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name IAMPolicyChanges \
  --filter-pattern '{($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)||($.eventName=AttachGroupPolicy)||($.eventName=DetachGroupPolicy)}' \
  --metric-transformations \
    metricName=IAMPolicyChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.5 - Ensure CloudTrail configuration changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name CloudTrailChanges \
  --filter-pattern '{($.eventName=CreateTrail)||($.eventName=UpdateTrail)||($.eventName=DeleteTrail)||($.eventName=StartLogging)||($.eventName=StopLogging)}' \
  --metric-transformations \
    metricName=CloudTrailChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.6 - Ensure AWS Management Console authentication failures are monitored
# (Already covered)

# 4.7 - Ensure disabling or deletion of CMKs is monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name CMKChanges \
  --filter-pattern '{($.eventSource=kms.amazonaws.com)&&(($.eventName=DisableKey)||($.eventName=ScheduleKeyDeletion))}' \
  --metric-transformations \
    metricName=CMKChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.8 - Ensure S3 bucket policy changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name S3BucketPolicyChanges \
  --filter-pattern '{($.eventSource=s3.amazonaws.com)&&(($.eventName=PutBucketAcl)||($.eventName=PutBucketPolicy)||($.eventName=PutBucketCors)||($.eventName=PutBucketLifecycle)||($.eventName=PutBucketReplication)||($.eventName=DeleteBucketPolicy)||($.eventName=DeleteBucketCors)||($.eventName=DeleteBucketLifecycle)||($.eventName=DeleteBucketReplication))}' \
  --metric-transformations \
    metricName=S3BucketPolicyChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.9 - Ensure AWS Config configuration changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name ConfigChanges \
  --filter-pattern '{($.eventSource=config.amazonaws.com)&&(($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder))}' \
  --metric-transformations \
    metricName=ConfigChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.10 - Ensure security group changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name SecurityGroupChanges \
  --filter-pattern '{($.eventName=AuthorizeSecurityGroupIngress)||($.eventName=AuthorizeSecurityGroupEgress)||($.eventName=RevokeSecurityGroupIngress)||($.eventName=RevokeSecurityGroupEgress)||($.eventName=CreateSecurityGroup)||($.eventName=DeleteSecurityGroup)}' \
  --metric-transformations \
    metricName=SecurityGroupChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.11 - Ensure Network Access Control Lists (NACL) changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name NACLChanges \
  --filter-pattern '{($.eventName=CreateNetworkAcl)||($.eventName=CreateNetworkAclEntry)||($.eventName=DeleteNetworkAcl)||($.eventName=DeleteNetworkAclEntry)||($.eventName=ReplaceNetworkAclEntry)||($.eventName=ReplaceNetworkAclAssociation)}' \
  --metric-transformations \
    metricName=NACLChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.12 - Ensure network gateway changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name NetworkGatewayChanges \
  --filter-pattern '{($.eventName=CreateCustomerGateway)||($.eventName=DeleteCustomerGateway)||($.eventName=AttachInternetGateway)||($.eventName=CreateInternetGateway)||($.eventName=DeleteInternetGateway)||($.eventName=DetachInternetGateway)}' \
  --metric-transformations \
    metricName=NetworkGatewayChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.13 - Ensure route table changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name RouteTableChanges \
  --filter-pattern '{($.eventName=CreateRoute)||($.eventName=CreateRouteTable)||($.eventName=ReplaceRoute)||($.eventName=ReplaceRouteTableAssociation)||($.eventName=DeleteRouteTable)||($.eventName=DeleteRoute)||($.eventName=DisassociateRouteTable)}' \
  --metric-transformations \
    metricName=RouteTableChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1

# 4.14 - Ensure VPC changes are monitored
aws logs put-metric-filter \
  --log-group-name /aws/cloudtrail/organization \
  --filter-name VPCChanges \
  --filter-pattern '{($.eventName=CreateVpc)||($.eventName=DeleteVpc)||($.eventName=ModifyVpcAttribute)||($.eventName=AcceptVpcPeeringConnection)||($.eventName=CreateVpcPeeringConnection)||($.eventName=DeleteVpcPeeringConnection)||($.eventName=RejectVpcPeeringConnection)||($.eventName=AttachClassicLinkVpc)||($.eventName=DetachClassicLinkVpc)||($.eventName=DisableVpcClassicLink)||($.eventName=EnableVpcClassicLink)}' \
  --metric-transformations \
    metricName=VPCChangesCount,\
    metricNamespace=CloudTrailMetrics,\
    metricValue=1
```

### 1.5 Networking

```bash
# 5.1 - Ensure no Network ACLs allow ingress from 0.0.0.0/0 to remote server administration ports
aws ec2 describe-network-acls \
  --query 'NetworkAcls[*].Entries[?RuleAction==`allow` && CidrBlock==`0.0.0.0/0`]'

# 5.2 - Ensure no security groups allow ingress from 0.0.0.0/0 to remote server administration ports
aws ec2 describe-security-groups \
  --query 'SecurityGroups[*].IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`) && (FromPort==`22` || FromPort==`3389`)]'

# 5.3 - Ensure the default security group restricts all traffic
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=default \
  --query 'SecurityGroups[?length(IpPermissions) > `0` || length(IpPermissionsEgress) > `1`]'

# 5.4 - Ensure routing tables for VPC peering are "least access"
# (Manual review required)
```

## Step 2: Security Metrics Dashboard

### 2.1 Create CloudWatch Dashboard

```bash
# Create comprehensive security dashboard
aws cloudwatch put-dashboard \
  --dashboard-name SecurityMetrics \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["CloudTrailMetrics", "RootAccountUsageCount"],
            [".", "UnauthorizedAPICallsCount"],
            [".", "ConsoleSignInFailureCount"],
            [".", "IAMPolicyChangesCount"]
          ],
          "period": 300,
          "stat": "Sum",
          "region": "us-east-1",
          "title": "Security Events"
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["AWS/GuardDuty", "FindingCount", {"stat": "Sum"}]
          ],
          "period": 3600,
          "stat": "Sum",
          "region": "us-east-1",
          "title": "GuardDuty Findings"
        }
      },
      {
        "type": "log",
        "properties": {
          "query": "SOURCE \"/aws/cloudtrail/organization\" | fields @timestamp, userIdentity.principalId, eventName, errorCode | filter errorCode like /Unauthorized/ or errorCode like /AccessDenied/ | sort @timestamp desc | limit 20",
          "region": "us-east-1",
          "title": "Recent Unauthorized Access Attempts"
        }
      }
    ]
  }'
```

### 2.2 Security Metrics Lambda

```python
# security_metrics.py
import boto3
import json
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')
guardduty = boto3.client('guardduty')
config = boto3.client('config')
securityhub = boto3.client('securityhub')

def lambda_handler(event, context):
    """
    Collect and publish security metrics
    """
    
    metrics = {
        'guardduty_findings': get_guardduty_metrics(),
        'config_compliance': get_config_compliance(),
        'security_hub_score': get_security_hub_score(),
        'iam_users_without_mfa': get_iam_mfa_status()
    }
    
    # Publish metrics to CloudWatch
    publish_metrics(metrics)
    
    # Generate report
    generate_report(metrics)
    
    return {
        'statusCode': 200,
        'body': json.dumps(metrics)
    }

def get_guardduty_metrics():
    """Get GuardDuty finding counts by severity"""
    
    detector_id = guardduty.list_detectors()['DetectorIds'][0]
    
    findings = guardduty.list_findings(
        DetectorId=detector_id,
        FindingCriteria={
            'Criterion': {
                'updatedAt': {
                    'Gte': int((datetime.now() - timedelta(days=1)).timestamp() * 1000)
                }
            }
        }
    )
    
    if not findings['FindingIds']:
        return {'high': 0, 'medium': 0, 'low': 0}
    
    finding_details = guardduty.get_findings(
        DetectorId=detector_id,
        FindingIds=findings['FindingIds']
    )
    
    severity_counts = {'high': 0, 'medium': 0, 'low': 0}
    for finding in finding_details['Findings']:
        severity = finding['Severity']
        if severity >= 7:
            severity_counts['high'] += 1
        elif severity >= 4:
            severity_counts['medium'] += 1
        else:
            severity_counts['low'] += 1
    
    return severity_counts

def get_config_compliance():
    """Get AWS Config compliance statistics"""
    
    response = config.describe_compliance_by_config_rule()
    
    compliant = 0
    non_compliant = 0
    
    for rule in response['ComplianceByConfigRules']:
        compliance_type = rule['Compliance']['ComplianceType']
        if compliance_type == 'COMPLIANT':
            compliant += 1
        elif compliance_type == 'NON_COMPLIANT':
            non_compliant += 1
    
    total = compliant + non_compliant
    compliance_percentage = (compliant / total * 100) if total > 0 else 0
    
    return {
        'compliant': compliant,
        'non_compliant': non_compliant,
        'percentage': compliance_percentage
    }

def get_security_hub_score():
    """Get Security Hub security score"""
    
    response = securityhub.get_findings(
        Filters={
            'WorkflowStatus': [{'Value': 'NEW', 'Comparison': 'EQUALS'}],
            'RecordState': [{'Value': 'ACTIVE', 'Comparison': 'EQUALS'}]
        }
    )
    
    critical = 0
    high = 0
    medium = 0
    low = 0
    
    for finding in response['Findings']:
        severity = finding['Severity']['Label']
        if severity == 'CRITICAL':
            critical += 1
        elif severity == 'HIGH':
            high += 1
        elif severity == 'MEDIUM':
            medium += 1
        else:
            low += 1
    
    return {
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low
    }

def get_iam_mfa_status():
    """Count IAM users without MFA"""
    
    iam = boto3.client('iam')
    users = iam.list_users()['Users']
    
    users_without_mfa = 0
    for user in users:
        mfa_devices = iam.list_mfa_devices(UserName=user['UserName'])
        if not mfa_devices['MFADevices']:
            users_without_mfa += 1
    
    return {
        'total_users': len(users),
        'without_mfa': users_without_mfa
    }

def publish_metrics(metrics):
    """Publish metrics to CloudWatch"""
    
    cloudwatch.put_metric_data(
        Namespace='SecurityMetrics',
        MetricData=[
            {
                'MetricName': 'GuardDutyHighSeverity',
                'Value': metrics['guardduty_findings']['high'],
                'Unit': 'Count'
            },
            {
                'MetricName': 'ConfigCompliancePercentage',
                'Value': metrics['config_compliance']['percentage'],
                'Unit': 'Percent'
            },
            {
                'MetricName': 'SecurityHubCriticalFindings',
                'Value': metrics['security_hub_score']['critical'],
                'Unit': 'Count'
            },
            {
                'MetricName': 'IAMUsersWithoutMFA',
                'Value': metrics['iam_users_without_mfa']['without_mfa'],
                'Unit': 'Count'
            }
        ]
    )

def generate_report(metrics):
    """Generate and send security report"""
    
    sns = boto3.client('sns')
    
    report = f"""
    Daily Security Metrics Report
    =============================
    
    GuardDuty Findings (Last 24h):
    - High Severity: {metrics['guardduty_findings']['high']}
    - Medium Severity: {metrics['guardduty_findings']['medium']}
    - Low Severity: {metrics['guardduty_findings']['low']}
    
    AWS Config Compliance:
    - Compliant Rules: {metrics['config_compliance']['compliant']}
    - Non-Compliant Rules: {metrics['config_compliance']['non_compliant']}
    - Compliance Rate: {metrics['config_compliance']['percentage']:.2f}%
    
    Security Hub Findings:
    - Critical: {metrics['security_hub_score']['critical']}
    - High: {metrics['security_hub_score']['high']}
    - Medium: {metrics['security_hub_score']['medium']}
    - Low: {metrics['security_hub_score']['low']}
    
    IAM Security:
    - Users without MFA: {metrics['iam_users_without_mfa']['without_mfa']} / {metrics['iam_users_without_mfa']['total_users']}
    """
    
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:ACCOUNT-ID:security-reports',
        Subject='Daily Security Metrics Report',
        Message=report
    )
```

### 2.3 Schedule Metrics Collection

```bash
# Create EventBridge rule for daily metrics
aws events put-rule \
  --name DailySecurityMetrics \
  --schedule-expression "cron(0 8 * * ? *)" \
  --state ENABLED

aws events put-targets \
  --rule DailySecurityMetrics \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT-ID:function:SecurityMetrics"
```

## Step 3: Compliance Reporting

### 3.1 Generate Compliance Report

```bash
# Export Security Hub findings
aws securityhub get-findings \
  --filters '{
    "ComplianceStatus": [{"Value": "FAILED", "Comparison": "EQUALS"}]
  }' \
  --output json > security-hub-findings.json

# Export Config compliance
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT \
  --output json > config-compliance.json

# Generate CSV report
python3 << 'EOF'
import json
import csv

# Load findings
with open('security-hub-findings.json') as f:
    findings = json.load(f)['Findings']

# Write to CSV
with open('compliance-report.csv', 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(['Title', 'Severity', 'Resource', 'Compliance Status', 'Remediation'])
    
    for finding in findings:
        writer.writerow([
            finding['Title'],
            finding['Severity']['Label'],
            finding['Resources'][0]['Id'],
            finding['Compliance']['Status'],
            finding.get('Remediation', {}).get('Recommendation', {}).get('Text', 'N/A')
        ])

print("Compliance report generated: compliance-report.csv")
EOF
```

## Security Best Practices

### ✅ DO
- Implement CIS benchmarks
- Monitor compliance continuously
- Generate regular reports
- Track security metrics
- Automate compliance checks
- Document exceptions
- Review findings regularly
- Update policies as needed

### ❌ DON'T
- Don't ignore compliance violations
- Don't skip regular audits
- Don't disable compliance checks
- Don't forget to document changes
- Don't ignore low severity findings
- Don't skip metric reviews

## Validation Checklist

- [ ] CIS benchmarks implemented
- [ ] CloudWatch metrics configured
- [ ] Security dashboard created
- [ ] Compliance reports automated
- [ ] Daily metrics collection scheduled
- [ ] SNS notifications configured
- [ ] Config rules deployed
- [ ] Security Hub standards enabled
- [ ] Regular audits scheduled

**Complete!** Your AWS security implementation is now comprehensive and production-ready.
