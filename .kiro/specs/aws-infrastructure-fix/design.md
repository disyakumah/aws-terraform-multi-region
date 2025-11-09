# Design Document

## Overview

This design document outlines the approach to fix and complete the Terraform configuration for a basic AWS infrastructure. The infrastructure consists of a VPC with public networking, security groups, and an EC2 web server instance. The design focuses on correcting syntax errors, adding missing resource definitions, and ensuring proper resource dependencies.

## Architecture

### High-Level Architecture

**Single Region View:**
```
Internet
    |
Internet Gateway
    |
VPC (10.0.0.0/16)
    |
    +-- Public Subnet (10.0.1.0/24)
    |   |
    |   +-- Public Route Table (default route to IGW)
    |   |
    |   +-- Public Security Group (HTTP/HTTPS from internet)
    |   |
    |   +-- Public EC2 Instance (t2.micro)
    |
    +-- Private Subnet (10.0.2.0/24)
        |
        +-- Private Route Table (local routes only)
        |
        +-- Private Security Group (traffic from public subnet)
        |
        +-- Private EC2 Instance (t2.micro)
```

**Multi-Region Architecture:**
```
Region: us-west-2              Region: us-east-1              Region: eu-west-1
VPC (10.0.0.0/16)              VPC (10.1.0.0/16)              VPC (10.2.0.0/16)
├── Public Subnet              ├── Public Subnet              ├── Public Subnet
│   └── EC2 Instance           │   └── EC2 Instance           │   └── EC2 Instance
└── Private Subnet             └── Private Subnet             └── Private Subnet
    └── EC2 Instance               └── EC2 Instance               └── EC2 Instance
```

Each region is deployed independently using the same reusable modules with region-specific configurations.

### Resource Dependencies

1. VPC (independent resource)
2. Internet Gateway (depends on VPC)
3. Public Subnet (depends on VPC)
4. Private Subnet (depends on VPC)
5. Public Route Table (depends on VPC and Internet Gateway)
6. Private Route Table (depends on VPC)
7. Public Route Table Association (depends on Public Subnet and Public Route Table)
8. Private Route Table Association (depends on Private Subnet and Private Route Table)
9. Public Security Group (depends on VPC)
10. Private Security Group (depends on VPC)
11. Public EC2 Instance (depends on Public Subnet and Public Security Group)
12. Private EC2 Instance (depends on Private Subnet and Private Security Group)

## Components and Interfaces

### 1. Root Module (main.tf)

**Purpose:** Orchestrate all child modules and define provider configuration

**Responsibilities:**
- Configure AWS provider with target region (supports multiple regions via provider aliases)
- Call VPC module with network configuration
- Call Security Group module with firewall rules
- Call EC2 module with instance specifications
- Pass outputs between modules
- Support multi-region deployment through for_each or multiple module calls

**Multi-Region Support:**
The root module can deploy to multiple regions using either:
- **Option A:** Multiple provider aliases with separate module calls per region
- **Option B:** for_each loop over a map of region configurations

### 2. VPC Module

**Purpose:** Create isolated virtual network with public and private subnets (region-agnostic)

**Inputs:**
- `vpc_cidr` - CIDR block for VPC (e.g., "10.0.0.0/16", "10.1.0.0/16" for different regions)
- `public_subnet_cidr` - CIDR block for public subnet (e.g., "10.0.1.0/24")
- `private_subnet_cidr` - CIDR block for private subnet (e.g., "10.0.2.0/24")
- `availability_zone` - AZ for subnet placement (e.g., "us-west-2a", "us-east-1a")
- `environment` - Environment name for tagging (e.g., "dev", "prod")
- `region` - AWS region name for tagging and identification (e.g., "us-west-2")

**Resources Created:**
- VPC with DNS support enabled
- Public subnet with auto-assign public IP
- Private subnet without public IP assignment
- Internet Gateway
- Public route table with default route to IGW
- Private route table with local routes only
- Route table associations for both subnets

**Outputs:**
- `vpc_id` - ID of created VPC
- `public_subnet_id` - ID of public subnet
- `private_subnet_id` - ID of private subnet
- `public_subnet_cidr` - CIDR block of public subnet
- `internet_gateway_id` - ID of internet gateway

### 3. Security Group Module

**Purpose:** Define firewall rules for resources

**Inputs:**
- `vpc_id` - VPC ID where security group will be created
- `name` - Name of the security group
- `description` - Description of the security group
- `ingress_rules` - List of ingress rule objects (port, protocol, cidr_blocks)
- `egress_rules` - List of egress rule objects (port, protocol, cidr_blocks)
- `tags` - Map of tags to apply

**Resources Created:**
- Security group with configurable ingress/egress rules

**Outputs:**
- `security_group_id` - ID of created security group

### 4. EC2 Module

**Purpose:** Create EC2 instances with specified configuration (region-agnostic)

**Inputs:**
- `ami_id` - AMI ID for the instance (region-specific, use data source for automatic lookup)
- `instance_type` - Instance type (e.g., "t2.micro")
- `subnet_id` - Subnet ID for instance placement
- `security_group_ids` - List of security group IDs
- `instance_name` - Name tag for the instance
- `additional_tags` - Additional tags to apply

**Note:** AMI IDs are region-specific. The module should use a data source to automatically find the latest Amazon Linux 2 AMI in the target region.

**Resources Created:**
- EC2 instance with specified configuration

**Outputs:**
- `instance_id` - ID of created instance
- `public_ip` - Public IP address of instance
- `private_ip` - Private IP address of instance

## Data Models

### Terraform Resource Structure

All resources follow the standard Terraform HCL syntax:

```hcl
resource "resource_type" "resource_name" {
  argument1 = "value1"
  argument2 = "value2"
  
  nested_block {
    nested_argument = "value"
  }
  
  tags = {
    Name = "tag_value"
  }
}
```

### Resource References

Resources reference each other using the syntax: `resource_type.resource_name.attribute`

Example: `aws_vpc.main.id` references the ID of the VPC resource named "main"

## Error Handling

### Syntax Errors to Fix

1. **Missing VPC Resource Block:** The configuration references `aws_vpc.main` but the resource definition is incomplete
2. **Missing Subnet Resource Block:** The configuration references `aws_subnet.public` but the resource is not defined
3. **Missing Internet Gateway Resource Block:** The configuration references `aws_internet_gateway.main` but the resource is not defined
4. **Incomplete Resource Block:** There's a malformed resource block with only a closing brace and tags

### Terraform Validation

After fixing the configuration:
- Run `terraform fmt` to format the code
- Run `terraform validate` to check syntax
- Run `terraform plan` to preview changes

## Testing Strategy

### Validation Steps

1. **Syntax Validation:**
   - Use `terraform fmt` to ensure proper formatting
   - Use `terraform validate` to check for syntax errors
   - Verify all resource blocks are complete and properly structured

2. **Configuration Validation:**
   - Verify all resource references are correct
   - Ensure CIDR blocks don't overlap
   - Confirm AMI ID is valid for us-west-2 region
   - Check that all required arguments are present

3. **Dependency Validation:**
   - Verify resource dependency chain is correct
   - Ensure resources are created in proper order
   - Confirm all referenced resources exist

### Manual Testing (Post-Implementation)

After the Terraform configuration is fixed:
1. Initialize Terraform: `terraform init`
2. Validate configuration: `terraform validate`
3. Preview changes: `terraform plan`
4. Apply configuration: `terraform apply` (optional, requires AWS credentials)

## Multi-Region Deployment Strategy

### Overview

The infrastructure is designed to be fully reusable across multiple AWS regions. This enables:
- High availability and disaster recovery
- Geographic distribution for lower latency
- Compliance with data residency requirements
- Easy expansion to new regions

### Implementation Approach

**Option 1: Provider Aliases (Recommended for 2-3 regions)**

```hcl
provider "aws" {
  alias  = "us_west"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

module "infrastructure_us_west" {
  source = "./modules/vpc"
  providers = {
    aws = aws.us_west
  }
  vpc_cidr = "10.0.0.0/16"
  region   = "us-west-2"
}

module "infrastructure_us_east" {
  source = "./modules/vpc"
  providers = {
    aws = aws.us_east
  }
  vpc_cidr = "10.1.0.0/16"
  region   = "us-east-1"
}
```

**Option 2: For-Each Loop (Recommended for 4+ regions)**

```hcl
locals {
  regions = {
    us_west = {
      region     = "us-west-2"
      vpc_cidr   = "10.0.0.0/16"
      public_cidr = "10.0.1.0/24"
      private_cidr = "10.0.2.0/24"
      az         = "us-west-2a"
    }
    us_east = {
      region     = "us-east-1"
      vpc_cidr   = "10.1.0.0/16"
      public_cidr = "10.1.1.0/24"
      private_cidr = "10.1.2.0/24"
      az         = "us-east-1a"
    }
    eu_west = {
      region     = "eu-west-1"
      vpc_cidr   = "10.2.0.0/16"
      public_cidr = "10.2.1.0/24"
      private_cidr = "10.2.2.0/24"
      az         = "eu-west-1a"
    }
  }
}

module "infrastructure" {
  for_each = local.regions
  source   = "./modules/vpc"
  
  providers = {
    aws = aws[each.key]
  }
  
  vpc_cidr            = each.value.vpc_cidr
  public_subnet_cidr  = each.value.public_cidr
  private_subnet_cidr = each.value.private_cidr
  availability_zone   = each.value.az
  region              = each.value.region
  environment         = var.environment
}
```

### Region-Specific Considerations

**CIDR Block Planning:**
- Each region must have non-overlapping CIDR blocks
- Recommended pattern: 10.X.0.0/16 where X is the region index
- Example: us-west-2 = 10.0.0.0/16, us-east-1 = 10.1.0.0/16, eu-west-1 = 10.2.0.0/16

**AMI Selection:**
- AMI IDs are region-specific
- Use data sources to automatically find the latest AMI in each region
- Example:
```hcl
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

**Availability Zones:**
- AZ names vary by region (e.g., us-west-2a, us-east-1a)
- Use data sources to dynamically fetch available AZs
- Consider deploying across multiple AZs within a region for higher availability

**State Management:**
- Use separate state files per region or use workspaces
- State file naming: `{environment}-{region}-terraform.tfstate`
- Example: `prod-us-west-2-terraform.tfstate`

## State Management and Versioning

### Terraform Version Pinning

The root module should specify required Terraform and provider versions:

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Remote State Backend (Optional but Recommended)

For production use, configure remote state storage:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Benefits:
- Team collaboration with shared state
- State locking prevents concurrent modifications
- Encrypted state storage
- State versioning and backup

## Implementation Notes

### File Structure

The configuration will be modularized for reusability:

```
Day3/
├── main.tf                    # Root module - multi-region orchestration
├── variables.tf               # Input variables for customization
├── outputs.tf                 # Output values from all regions
├── locals.tf                  # Local values including region configurations
├── terraform.tfvars.example   # Example variable values (committed to git)
├── terraform.tfvars           # Actual variable values (not committed to git)
├── .gitignore                 # Ignore .terraform/, *.tfstate, *.tfvars
└── modules/
    ├── vpc/
    │   ├── main.tf            # VPC, public/private subnets, IGW, route tables
    │   ├── variables.tf       # VPC module inputs with descriptions
    │   ├── outputs.tf         # VPC module outputs (vpc_id, subnet_ids, etc.)
    │   ├── data.tf            # Data sources (AMI lookup, AZ lookup)
    │   └── README.md          # Module documentation and usage examples
    ├── security-group/
    │   ├── main.tf            # Security group definition
    │   ├── variables.tf       # SG module inputs with descriptions
    │   ├── outputs.tf         # SG module outputs (security_group_id)
    │   └── README.md          # Module documentation
    └── ec2/
        ├── main.tf            # EC2 instance definition
        ├── variables.tf       # EC2 module inputs with descriptions
        ├── outputs.tf         # EC2 module outputs (instance_id, public_ip, private_ip)
        ├── data.tf            # Data sources (latest AMI lookup)
        └── README.md          # Module documentation
```

### Module Design

**VPC Module:**
- Creates VPC, public subnet, private subnet, internet gateway, route tables, and associations
- Inputs: vpc_cidr, public_subnet_cidr, private_subnet_cidr, availability_zone, environment
- Outputs: vpc_id, public_subnet_id, private_subnet_id, public_subnet_cidr, internet_gateway_id

**Security Group Module:**
- Creates security group with configurable ingress/egress rules
- Inputs: vpc_id, security_group_name, ingress_rules, egress_rules, tags
- Outputs: security_group_id

**EC2 Module:**
- Creates EC2 instance with configurable parameters
- Inputs: ami_id, instance_type, subnet_id, security_group_ids, instance_name, additional_tags
- Outputs: instance_id, public_ip, private_ip

### Resource Ordering

Resources should be ordered logically in the root main.tf:
1. Provider configuration
2. VPC module call (creates VPC, public/private subnets, IGW, route tables)
3. Public Security Group module call (depends on VPC)
4. Private Security Group module call (depends on VPC, uses public subnet CIDR)
5. Public EC2 module call (depends on VPC and Public Security Group)
6. Private EC2 module call (depends on VPC and Private Security Group)

This ordering improves readability and follows the dependency chain.

### Best Practices Applied

**Code Organization:**
- Use consistent naming conventions (e.g., "main" for core networking, "public" for public-facing resources)
- Modularize infrastructure for reusability across environments and regions
- Follow DRY (Don't Repeat Yourself) principles - write once, reuse everywhere
- Clear separation of concerns with dedicated modules
- Region-agnostic modules that work in any AWS region

**Security:**
- Private subnet has no direct internet access (no IGW route)
- Security groups follow principle of least privilege
- Private resources only accept traffic from public subnet
- Use security group IDs instead of CIDR blocks where possible for internal communication

**Variables and Outputs:**
- Use variables for all configurable values (no hardcoded values)
- Provide sensible default values where appropriate
- Add descriptions to all variables and outputs
- Expose outputs for module integration and debugging

**Resource Configuration:**
- Add descriptive tags to all resources for cost tracking and management
- Enable DNS support and hostnames in VPC for proper name resolution
- Use explicit resource references instead of hardcoded IDs
- Enable auto-assignment of public IPs only for public subnet instances

**State Management:**
- Use remote state backend (S3 + DynamoDB) for team collaboration (recommended for production)
- Enable state locking to prevent concurrent modifications
- Use workspaces for environment separation (dev, staging, prod)

**Version Control:**
- Pin Terraform version in configuration
- Pin provider versions to avoid breaking changes
- Use semantic versioning for modules

**Documentation:**
- Add comments explaining complex logic
- Document module inputs, outputs, and usage examples
- Include README.md in each module directory

### Reusability Benefits

- Modules can be reused across multiple environments (dev, staging, prod)
- Modules can be reused across multiple AWS regions without modification
- Easy to customize via input variables
- Simplified testing and maintenance
- Clear separation of concerns
- Can version and share modules across projects
- Consistent infrastructure across teams, projects, and regions
- Easy to add new regions by updating configuration, not code
- Supports multi-region disaster recovery and high availability strategies
