# AWS Control Tower Setup
## Foundation Security for Multi-Account AWS Environments

### 🎯 What is AWS Control Tower?

AWS Control Tower provides the easiest way to set up and govern a secure, multi-account AWS environment based on best practices. It automates the setup of a baseline environment, or landing zone, that is a secure, well-architected multi-account AWS environment.

### 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    MANAGEMENT ACCOUNT                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           AWS Control Tower                             │   │
│  │  • Account Factory                                      │   │
│  │  • Guardrails (Preventive & Detective)                 │   │
│  │  • Dashboard & Compliance                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY OU                                  │
│  ┌──────────────────────┐  ┌──────────────────────┐           │
│  │   Log Archive        │  │   Audit Account      │           │
│  │   Account            │  │                      │           │
│  │  • CloudTrail logs   │  │  • Security Hub      │           │
│  │  • Config logs       │  │  • GuardDuty         │           │
│  │  • VPC Flow logs     │  │  • Access Analyzer   │           │
│  └──────────────────────┘  └──────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    WORKLOAD OUs                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Production   │  │   Staging    │  │ Development  │         │
│  │   Account    │  │   Account    │  │   Account    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

### Required Permissions
- Root user access or Administrator access to AWS account
- Email addresses for new accounts (unique per account)
- AWS Organizations enabled

### Cost Considerations
- Control Tower itself: **Free**
- AWS Config: ~$2-5 per account/month
- CloudTrail: ~$2-10 per account/month
- Additional services (GuardDuty, Security Hub): Variable

---

## 🚀 Step-by-Step Implementation

### Step 1: Pre-Setup Checklist

**Before enabling Control Tower:**

```bash
# 1. Verify you're in the management account
aws sts get-caller-identity

# 2. Check if Organizations is already enabled
aws organizations describe-organization

# 3. Verify region selection (choose your home region)
# Recommended: us-east-1, eu-west-1, or ap-southeast-1
```

**Important Decisions:**

1. **Home Region**: Where Control Tower will be deployed
   - Choose based on: data residency, latency, compliance
   - Cannot be changed after setup

2. **Governed Regions**: Additional regions to govern
   - Start with 2-3 regions
   - Can add more later

3. **Email Addresses Needed**:
   - Log Archive account: `aws-logs@yourcompany.com`
   - Audit account: `aws-audit@yourcompany.com`

---

### Step 2: Enable AWS Control Tower

#### Via AWS Console:

1. **Navigate to Control Tower**
   ```
   AWS Console → Search "Control Tower" → Get Started
   ```

2. **Review Pricing and Select Region**
   - Select your home region
   - Review estimated costs
   - Click "Set up landing zone"

3. **Configure Landing Zone**

   **Region Selection:**
   ```
   Home Region: us-east-1 (example)
   
   Additional Governed Regions:
   ☑ us-west-2
   ☑ eu-west-1
   ```

   **Organizational Units:**
   ```
   ☑ Security OU (required)
   ☑ Sandbox OU (optional, recommended)
   ```

   **Account Configuration:**
   ```
   Log Archive Account Email: aws-logs@yourcompany.com
   Audit Account Email: aws-audit@yourcompany.com
   ```

4. **Review and Confirm**
   - Review all settings
   - Click "Set up landing zone"
   - **Wait 60-90 minutes** for setup to complete

---

### Step 3: Verify Control Tower Setup

```bash
# 1. Check Control Tower status
aws controltower list-landing-zones --region us-east-1

# 2. Verify Organizations structure
aws organizations list-organizational-units-for-parent \
  --parent-id r-xxxx

# 3. List all accounts
aws organizations list-accounts

# Expected output:
# - Management Account
# - Log Archive Account
# - Audit Account
```

**Via Console Verification:**

1. Navigate to Control Tower Dashboard
2. Verify:
   - ✅ Landing zone status: "Available"
   - ✅ 2 OUs created (Security, Sandbox)
   - ✅ 3 accounts total
   - ✅ Guardrails enabled

---

### Step 4: Configure Guardrails

Guardrails are pre-configured governance rules. There are three types:

#### Mandatory Guardrails (Always Enabled)
```
✓ Disallow changes to CloudTrail
✓ Disallow deletion of log archives
✓ Enable CloudTrail in all regions
✓ Enable AWS Config in all regions
```

#### Strongly Recommended Guardrails

**Enable these immediately:**

1. **Navigate to Guardrails**
   ```
   Control Tower → Guardrails → Library
   ```

2. **Enable Key Guardrails:**

   **Identity & Access:**
   ```
   ☑ Disallow public read access to S3 buckets
   ☑ Disallow public write access to S3 buckets
   ☑ Detect whether MFA is enabled for root user
   ☑ Detect whether public access to RDS is enabled
   ```

   **Data Protection:**
   ```
   ☑ Detect whether EBS volumes are encrypted
   ☑ Detect whether RDS storage is encrypted
   ☑ Detect whether S3 buckets have encryption enabled
   ```

   **Network Security:**
   ```
   ☑ Disallow internet connection through RDP
   ☑ Disallow unrestricted SSH access
   ☑ Detect whether VPC flow logging is enabled
   ```

#### Enable Guardrails via CLI:

```bash
# Enable a guardrail on an OU
aws controltower enable-control \
  --control-identifier arn:aws:controltower:us-east-1::control/AWS-GR_RESTRICT_ROOT_USER_ACCESS_KEYS \
  --target-identifier arn:aws:organizations::123456789012:ou/o-xxxx/ou-xxxx-xxxx
```

---

### Step 5: Create Additional Organizational Units

**Recommended OU Structure:**

```
Root
├── Security (created by Control Tower)
│   ├── Log Archive Account
│   └── Audit Account
├── Infrastructure
│   ├── Shared Services Account
│   └── Network Account
├── Workloads
│   ├── Production OU
│   ├── Staging OU
│   └── Development OU
└── Sandbox (created by Control Tower)
    └── Individual developer accounts
```

**Create OUs via Console:**

1. Navigate to: `Control Tower → Organization → Create organizational unit`
2. Create each OU:
   ```
   Name: Infrastructure
   Parent: Root
   
   Name: Workloads
   Parent: Root
   
   Name: Production
   Parent: Workloads
   
   Name: Staging
   Parent: Workloads
   
   Name: Development
   Parent: Workloads
   ```

**Create OUs via CLI:**

```bash
# Get root ID
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)

# Create Infrastructure OU
aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Infrastructure

# Create Workloads OU
WORKLOADS_OU=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Workloads \
  --query 'OrganizationalUnit.Id' \
  --output text)

# Create child OUs under Workloads
aws organizations create-organizational-unit \
  --parent-id $WORKLOADS_OU \
  --name Production

aws organizations create-organizational-unit \
  --parent-id $WORKLOADS_OU \
  --name Staging

aws organizations create-organizational-unit \
  --parent-id $WORKLOADS_OU \
  --name Development
```

---

### Step 6: Provision New Accounts with Account Factory

**Account Factory** automates account creation with security baselines.

#### Via Console:

1. **Navigate to Account Factory**
   ```
   Control Tower → Account Factory → Create account
   ```

2. **Configure Account Details:**
   ```
   Account email: production-app@yourcompany.com
   Display name: Production-Application
   AWS SSO user email: admin@yourcompany.com
   AWS SSO user name: ProductionAdmin
   
   Organizational unit: Workloads/Production
   ```

3. **Submit and Wait**
   - Account creation takes 20-30 minutes
   - Automatically applies guardrails
   - Configures baseline security

#### Via CLI (Service Catalog):

```bash
# 1. Get Account Factory product ID
PRODUCT_ID=$(aws servicecatalog search-products \
  --filters FullTextSearch="AWS Control Tower Account Factory" \
  --query 'ProductViewSummaries[0].ProductId' \
  --output text)

# 2. Get provisioning artifact ID
ARTIFACT_ID=$(aws servicecatalog describe-product \
  --id $PRODUCT_ID \
  --query 'ProvisioningArtifacts[0].Id' \
  --output text)

# 3. Provision new account
aws servicecatalog provision-product \
  --product-id $PRODUCT_ID \
  --provisioning-artifact-id $ARTIFACT_ID \
  --provisioned-product-name "Production-Application" \
  --provisioning-parameters \
    Key=AccountEmail,Value=production-app@yourcompany.com \
    Key=AccountName,Value=Production-Application \
    Key=ManagedOrganizationalUnit,Value="Workloads/Production" \
    Key=SSOUserEmail,Value=admin@yourcompany.com \
    Key=SSOUserFirstName,Value=Production \
    Key=SSOUserLastName,Value=Admin
```

---

### Step 7: Configure AWS SSO (IAM Identity Center)

Control Tower automatically enables AWS SSO for centralized access.

#### Setup SSO Users and Groups:

1. **Navigate to IAM Identity Center**
   ```
   AWS Console → IAM Identity Center
   ```

2. **Create Groups:**
   ```
   Group: SecurityAdmins
   Description: Security team with audit access
   
   Group: Developers
   Description: Development team with limited access
   
   Group: Operations
   Description: Operations team with infrastructure access
   ```

3. **Create Users:**
   ```
   User: john.doe@company.com
   First name: John
   Last name: Doe
   Groups: Developers
   ```

4. **Assign Permission Sets:**

   **For SecurityAdmins:**
   ```
   Permission set: SecurityAudit (AWS managed)
   Accounts: All accounts
   ```

   **For Developers:**
   ```
   Permission set: PowerUserAccess (AWS managed)
   Accounts: Development accounts only
   ```

   **For Operations:**
   ```
   Permission set: AdministratorAccess (AWS managed)
   Accounts: Infrastructure accounts
   ```

#### CLI Configuration:

```bash
# 1. Get SSO instance ARN
SSO_INSTANCE=$(aws sso-admin list-instances \
  --query 'Instances[0].InstanceArn' \
  --output text)

# 2. Create permission set
aws sso-admin create-permission-set \
  --instance-arn $SSO_INSTANCE \
  --name DeveloperAccess \
  --description "Developer access with limited permissions"

# 3. Attach managed policy to permission set
aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn $SSO_INSTANCE \
  --permission-set-arn <permission-set-arn> \
  --managed-policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

---

### Step 8: Enable Additional Security Services

#### Enable in Audit Account:

```bash
# Switch to Audit account
aws sts assume-role \
  --role-arn arn:aws:iam::AUDIT-ACCOUNT-ID:role/AWSControlTowerExecution \
  --role-session-name security-setup

# Enable Security Hub
aws securityhub enable-security-hub \
  --enable-default-standards

# Enable GuardDuty
aws guardduty create-detector \
  --enable

# Enable IAM Access Analyzer
aws accessanalyzer create-analyzer \
  --analyzer-name organization-analyzer \
  --type ORGANIZATION
```

---

## ✅ Verification Checklist

After setup, verify the following:

### Control Tower Status
- [ ] Landing zone status: "Available"
- [ ] All guardrails enabled successfully
- [ ] No drift detected

### Account Structure
- [ ] Management account configured
- [ ] Log Archive account created
- [ ] Audit account created
- [ ] Custom OUs created
- [ ] Test account provisioned successfully

### Security Services
- [ ] CloudTrail enabled in all regions
- [ ] AWS Config enabled in all accounts
- [ ] Security Hub enabled in Audit account
- [ ] GuardDuty enabled in Audit account

### Access Management
- [ ] AWS SSO configured
- [ ] User groups created
- [ ] Permission sets assigned
- [ ] MFA enforced for privileged users

---

## 🔧 Troubleshooting

### Issue: Landing Zone Setup Failed

**Symptoms:**
- Setup stuck at "In Progress"
- Error message in Control Tower console

**Solutions:**

```bash
# 1. Check CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_FAILED \
  --query 'StackSummaries[?contains(StackName, `AWSControlTower`)]'

# 2. Review stack events for errors
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --max-items 20

# 3. Common fixes:
# - Ensure no existing AWS Config recorder
# - Verify email addresses are unique
# - Check service limits (especially VPCs)
```

### Issue: Account Factory Provisioning Failed

**Check Service Catalog:**

```bash
# Get provisioned product details
aws servicecatalog describe-provisioned-product \
  --id <provisioned-product-id>

# Check for errors in outputs
```

**Common causes:**
- Email already in use
- Invalid OU path
- SSO user already exists

### Issue: Guardrail Compliance Violations

**View violations:**

```bash
# List non-compliant resources
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT

# Get specific rule details
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name <rule-name> \
  --compliance-types NON_COMPLIANT
```

---

## 📊 Monitoring Control Tower

### Dashboard Metrics

**Key metrics to monitor:**

1. **Account Compliance**
   - Guardrail violations
   - Drift detection
   - Config rule compliance

2. **Account Provisioning**
   - New accounts created
   - Provisioning failures
   - Time to provision

### CloudWatch Alarms

```bash
# Create alarm for guardrail violations
aws cloudwatch put-metric-alarm \
  --alarm-name control-tower-guardrail-violations \
  --alarm-description "Alert on guardrail violations" \
  --metric-name NonCompliantResources \
  --namespace AWS/Config \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

---

## 🎓 Best Practices

### 1. Account Strategy
- **Separate accounts** for different environments (dev/staging/prod)
- **Dedicated security account** for centralized security tooling
- **Shared services account** for common resources (DNS, Active Directory)

### 2. Guardrail Management
- Start with **mandatory + strongly recommended** guardrails
- Add **elective guardrails** based on compliance requirements
- Regularly review and update guardrail policies

### 3. Access Management
- Use **AWS SSO** for all human access
- Implement **MFA** for all users
- Follow **least privilege** principle
- Regular access reviews (quarterly)

### 4. Monitoring
- Enable **CloudTrail** in all regions
- Centralize logs in **Log Archive account**
- Set up **alerts** for critical guardrail violations
- Regular compliance audits

### 5. Account Lifecycle
- Use **Account Factory** for all new accounts
- Implement **account tagging** strategy
- Document account purpose and ownership
- Regular account cleanup (close unused accounts)

---

## 📚 Additional Resources

- [AWS Control Tower User Guide](https://docs.aws.amazon.com/controltower/)
- [AWS Multi-Account Strategy](https://aws.amazon.com/organizations/getting-started/best-practices/)
- [Guardrails Reference](https://docs.aws.amazon.com/controltower/latest/userguide/guardrails-reference.html)

---

**Next Steps:**
- Proceed to [IAM Best Practices](02-iam-security.md)
- Review [Account Structure Guide](03-account-structure.md)
