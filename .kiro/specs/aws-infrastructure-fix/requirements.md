# Requirements Document

## Introduction

This document defines the requirements for fixing and completing a Terraform configuration that provisions a basic AWS infrastructure including VPC networking components, security groups, and an EC2 web server instance in the us-west-2 region.

## Glossary

- **Terraform Configuration**: Infrastructure as Code (IaC) files written in HashiCorp Configuration Language (HCL) that define AWS resources
- **VPC (Virtual Private Cloud)**: An isolated virtual network within AWS
- **Subnet**: A logical subdivision of an IP network within a VPC
- **Internet Gateway**: A VPC component that allows communication between the VPC and the internet
- **Route Table**: A set of rules that determine where network traffic is directed
- **Security Group**: A virtual firewall that controls inbound and outbound traffic for AWS resources
- **EC2 Instance**: A virtual server in AWS Elastic Compute Cloud
- **CIDR Block**: Classless Inter-Domain Routing notation for IP address ranges

## Requirements

### Requirement 1

**User Story:** As a DevOps engineer, I want a syntactically correct Terraform configuration, so that I can successfully provision AWS infrastructure without errors

#### Acceptance Criteria

1. THE Terraform Configuration SHALL define all referenced AWS resources with complete and valid HCL syntax
2. WHEN the Terraform Configuration is validated, THE Terraform Configuration SHALL produce no syntax errors
3. THE Terraform Configuration SHALL include all required resource blocks that are referenced by other resources
4. THE Terraform Configuration SHALL use consistent resource naming conventions throughout all resource definitions

### Requirement 2

**User Story:** As a network administrator, I want a complete VPC networking setup with both public and private subnets, so that I can deploy resources with appropriate internet access levels

#### Acceptance Criteria

1. THE Terraform Configuration SHALL create a VPC resource with a CIDR block of 10.0.0.0/16
2. THE Terraform Configuration SHALL create a public subnet resource with a CIDR block within the VPC range
3. THE Terraform Configuration SHALL create a private subnet resource with a CIDR block within the VPC range that does not overlap with the public subnet
4. THE Terraform Configuration SHALL create an Internet Gateway resource attached to the VPC
5. THE Terraform Configuration SHALL enable automatic public IP assignment for instances in the public subnet
6. THE Terraform Configuration SHALL create a public route table with a default route pointing to the Internet Gateway
7. THE Terraform Configuration SHALL create a private route table for the private subnet
8. THE Terraform Configuration SHALL associate the public route table with the public subnet
9. THE Terraform Configuration SHALL associate the private route table with the private subnet

### Requirement 3

**User Story:** As a security engineer, I want properly configured security groups for both public and private resources, so that only necessary traffic is allowed

#### Acceptance Criteria

1. THE Terraform Configuration SHALL create a public security group that allows inbound HTTP traffic on port 80 from any source
2. THE Terraform Configuration SHALL create a public security group that allows inbound HTTPS traffic on port 443 from any source
3. THE Terraform Configuration SHALL create a public security group that allows all outbound traffic
4. THE Terraform Configuration SHALL create a private security group that allows inbound traffic only from the public subnet CIDR block
5. THE Terraform Configuration SHALL create a private security group that allows all outbound traffic
6. THE Terraform Configuration SHALL attach all security groups to the VPC

### Requirement 4

**User Story:** As a system administrator, I want properly configured EC2 instances in both public and private subnets, so that I can deploy multi-tier applications

#### Acceptance Criteria

1. THE Terraform Configuration SHALL create a public EC2 instance with instance type t2.micro in the public subnet
2. THE Terraform Configuration SHALL create a private EC2 instance with instance type t2.micro in the private subnet
3. THE Terraform Configuration SHALL use a valid Amazon Linux 2 AMI for the us-west-2 region for all instances
4. THE Terraform Configuration SHALL attach the public security group to the public EC2 instance
5. THE Terraform Configuration SHALL attach the private security group to the private EC2 instance
6. THE Terraform Configuration SHALL assign appropriate tags to all EC2 instances for identification

### Requirement 5

**User Story:** As a DevOps engineer, I want all resources properly tagged, so that I can track and manage infrastructure resources effectively

#### Acceptance Criteria

1. THE Terraform Configuration SHALL assign a Name tag to every AWS resource
2. THE Terraform Configuration SHALL use descriptive and consistent naming in all resource tags
