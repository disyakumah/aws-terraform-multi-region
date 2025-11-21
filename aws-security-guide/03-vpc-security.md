# VPC Security Design

## Overview
This guide covers comprehensive VPC security implementation including network segmentation, security groups, NACLs, and environment isolation.

## Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Public Subnet (10.0.1.0/24)                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │   ALB    │  │   NAT    │  │ Bastion  │              │  │
│  │  │          │  │ Gateway  │  │   Host   │              │  │
│  │  └──────────┘  └──────────┘  └──────────┘              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │             Private Subnet (10.0.2.0/24)                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │   App    │  │   App    │  │   App    │              │  │
│  │  │ Server 1 │  │ Server 2 │  │ Server 3 │              │  │
│  │  └──────────┘  └──────────┘  └──────────┘              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Database Subnet (10.0.3.0/24)                 │  │
│  │  ┌──────────┐  ┌──────────┐                             │  │
│  │  │   RDS    │  │   RDS    │                             │  │
│  │  │ Primary  │  │ Standby  │                             │  │
│  │  └──────────┘  └──────────┘                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: Create Secure VPC

### 1.1 VPC Configuration

```bash
# Create VPC with DNS support
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --enable-dns-support \
  --enable-dns-hostnames \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=production-vpc},{Key=Environment,Value=production}]'

# Enable VPC Flow Logs (CRITICAL for security monitoring)
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs \
  --deliver-logs-permission-arn arn:aws:iam::ACCOUNT-ID:role/VPCFlowLogsRole
```

### 1.2 Subnet Design

**Security Principle:** Three-tier architecture with network isolation

```bash
# Public Subnet (for load balancers, NAT gateways)
aws ec2 create-subnet \
  --vpc-id vpc-xxxxx \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-1a},{Key=Tier,Value=public}]'

# Private Subnet (for application servers)
aws ec2 create-subnet \
  --vpc-id vpc-xxxxx \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1a},{Key=Tier,Value=private}]'

# Database Subnet (for databases only)
aws ec2 create-subnet \
  --vpc-id vpc-xxxxx \
  --cidr-block 10.0.3.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=database-subnet-1a},{Key=Tier,Value=database}]'
```

## Step 2: Security Groups (Stateful Firewall)

### 2.1 ALB Security Group

```bash
# Create ALB security group
aws ec2 create-security-group \
  --group-name alb-sg \
  --description "Security group for Application Load Balancer" \
  --vpc-id vpc-xxxxx

# Allow HTTPS from internet
aws ec2 authorize-security-group-ingress \
  --group-id sg-alb-xxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Allow HTTP (redirect to HTTPS)
aws ec2 authorize-security-group-ingress \
  --group-id sg-alb-xxxxx \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

### 2.2 Application Server Security Group

```bash
# Create app server security group
aws ec2 create-security-group \
  --group-name app-server-sg \
  --description "Security group for application servers" \
  --vpc-id vpc-xxxxx

# Allow traffic ONLY from ALB
aws ec2 authorize-security-group-ingress \
  --group-id sg-app-xxxxx \
  --protocol tcp \
  --port 8080 \
  --source-group sg-alb-xxxxx

# Allow SSH from bastion host only
aws ec2 authorize-security-group-ingress \
  --group-id sg-app-xxxxx \
  --protocol tcp \
  --port 22 \
  --source-group sg-bastion-xxxxx
```

### 2.3 Database Security Group

```bash
# Create database security group
aws ec2 create-security-group \
  --group-name database-sg \
  --description "Security group for RDS databases" \
  --vpc-id vpc-xxxxx

# Allow database connections ONLY from app servers
aws ec2 authorize-security-group-ingress \
  --group-id sg-db-xxxxx \
  --protocol tcp \
  --port 5432 \
  --source-group sg-app-xxxxx
```

### 2.4 Bastion Host Security Group

```bash
# Create bastion security group
aws ec2 create-security-group \
  --group-name bastion-sg \
  --description "Security group for bastion host" \
  --vpc-id vpc-xxxxx

# Allow SSH from corporate IP only
aws ec2 authorize-security-group-ingress \
  --group-id sg-bastion-xxxxx \
  --protocol tcp \
  --port 22 \
  --cidr YOUR-CORPORATE-IP/32
```

## Step 3: Network ACLs (Stateless Firewall)

### 3.1 Public Subnet NACL

```bash
# Create NACL for public subnet
aws ec2 create-network-acl \
  --vpc-id vpc-xxxxx \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=public-nacl}]'

# Inbound Rules
# Allow HTTPS
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxxxx \
  --ingress \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow

# Allow HTTP
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxxxx \
  --ingress \
  --rule-number 110 \
  --protocol tcp \
  --port-range From=80,To=80 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow

# Allow return traffic (ephemeral ports)
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxxxx \
  --ingress \
  --rule-number 120 \
  --protocol tcp \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow

# Outbound Rules
# Allow all outbound (can be restricted further)
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxxxx \
  --egress \
  --rule-number 100 \
  --protocol -1 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow
```

### 3.2 Private Subnet NACL

```bash
# Create NACL for private subnet
aws ec2 create-network-acl \
  --vpc-id vpc-xxxxx \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=private-nacl}]'

# Allow traffic from public subnet
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxxxx \
  --ingress \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=8080,To=8080 \
  --cidr-block 10.0.1.0/24 \
  --rule-action allow

# Allow SSH from bastion
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxxxx \
  --ingress \
  --rule-number 110 \
  --protocol tcp \
  --port-range From=22,To=22 \
  --cidr-block 10.0.1.0/24 \
  --rule-action allow
```

## Step 4: VPC Endpoints (Private AWS Service Access)

### 4.1 Gateway Endpoints (S3, DynamoDB)

```bash
# Create S3 VPC Endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxxxx \
  --service-name com.amazonaws.us-east-1.s3 \
  --route-table-ids rtb-xxxxx \
  --policy-document '{
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource": "arn:aws:s3:::my-secure-bucket/*"
      }
    ]
  }'
```

### 4.2 Interface Endpoints (Other AWS Services)

```bash
# Create EC2 VPC Endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxxxx \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.ec2 \
  --subnet-ids subnet-xxxxx \
  --security-group-ids sg-xxxxx
```

## Step 5: NAT Gateway Setup

```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Create NAT Gateway
aws ec2 create-nat-gateway \
  --subnet-id subnet-public-xxxxx \
  --allocation-id eipalloc-xxxxx \
  --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=production-nat}]'

# Update private subnet route table
aws ec2 create-route \
  --route-table-id rtb-private-xxxxx \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-xxxxx
```

## Step 6: Environment Separation

### 6.1 Production VPC (10.0.0.0/16)

```bash
# Production VPC - Strict security
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=production-vpc},{Key=Environment,Value=production}]'
```

### 6.2 Staging VPC (10.1.0.0/16)

```bash
# Staging VPC - Moderate security
aws ec2 create-vpc \
  --cidr-block 10.1.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=staging-vpc},{Key=Environment,Value=staging}]'
```

### 6.3 Development VPC (10.2.0.0/16)

```bash
# Development VPC - Relaxed security
aws ec2 create-vpc \
  --cidr-block 10.2.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=development-vpc},{Key=Environment,Value=development}]'
```

## Security Best Practices

### ✅ DO
- Use three-tier architecture (public, private, database)
- Enable VPC Flow Logs for all VPCs
- Use VPC endpoints for AWS service access
- Implement least privilege in security groups
- Use separate VPCs for different environments
- Enable DNS resolution and hostnames
- Use NAT Gateways (not NAT instances)
- Tag all resources consistently

### ❌ DON'T
- Don't allow 0.0.0.0/0 in security groups (except ALB)
- Don't put databases in public subnets
- Don't use default VPC for production
- Don't share security groups across environments
- Don't allow SSH from 0.0.0.0/0
- Don't disable VPC Flow Logs
- Don't use overly broad CIDR blocks

## Terraform Implementation

```hcl
# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "production-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

## Validation Checklist

- [ ] VPC Flow Logs enabled
- [ ] Three-tier subnet architecture implemented
- [ ] Security groups follow least privilege
- [ ] NACLs configured for defense in depth
- [ ] VPC endpoints created for AWS services
- [ ] NAT Gateway deployed in public subnet
- [ ] Separate VPCs for each environment
- [ ] All resources properly tagged
- [ ] No public database access
- [ ] Bastion host properly secured

**Next:** [Data Protection & Encryption](04-data-protection.md)
