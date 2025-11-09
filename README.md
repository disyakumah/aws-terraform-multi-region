# Multi-Region AWS Infrastructure with Terraform

A production-ready, reusable Terraform infrastructure for deploying AWS resources across multiple regions.

## 🏗️ Architecture

This project deploys a complete AWS infrastructure with:
- **VPC** with DNS support
- **Public & Private Subnets** in each region
- **Internet Gateway** for public internet access
- **Route Tables** with proper routing configuration
- **Security Groups** (public allows HTTP/HTTPS, private isolated)
- **EC2 Instances** (t2.micro with auto-selected Amazon Linux 2 AMI)

## 🌍 Multi-Region Support

Currently configured for 3 regions:
- **us-west-2** (10.0.0.0/16)
- **us-east-1** (10.1.0.0/16)
- **eu-west-1** (10.2.0.0/16)

Each region deploys **12 resources** for a total of **36 resources** across all regions.

## 📁 Project Structure

```
Day3/
├── main.tf              # Root module - multi-region orchestration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── locals.tf            # Region configurations
├── .gitignore          # Git ignore rules
├── terraform.tfvars.example  # Example configuration
└── modules/
    ├── vpc/            # VPC module (networking)
    ├── security-group/ # Security group module
    └── ec2/            # EC2 instance module
```

## 🚀 Quick Start

### Prerequisites
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with credentials
- AWS account with appropriate permissions

### Deploy Infrastructure

1. **Initialize Terraform:**
   ```bash
   cd Day3
   terraform init
   ```

2. **Preview changes:**
   ```bash
   terraform plan
   ```

3. **Deploy to all regions:**
   ```bash
   terraform apply
   ```

4. **Deploy to single region (testing):**
   ```bash
   terraform apply -target="module.vpc_us_west" \
                   -target="module.sg_public_us_west" \
                   -target="module.sg_private_us_west" \
                   -target="module.ec2_public_us_west" \
                   -target="module.ec2_private_us_west"
   ```

### Destroy Infrastructure

```bash
terraform destroy
```

## 🔧 Customization

### Add a New Region

Edit `Day3/locals.tf` and add your region:

```hcl
locals {
  regions = {
    # ... existing regions ...
    ap_south = {
      region           = "ap-south-1"
      vpc_cidr         = "10.3.0.0/16"
      public_cidr      = "10.3.1.0/24"
      private_cidr     = "10.3.2.0/24"
      az               = "ap-south-1a"
    }
  }
}
```

Then add the corresponding module calls in `main.tf`.

### Change Environment

Modify the `environment` variable in `Day3/variables.tf` or create a `terraform.tfvars` file:

```hcl
environment = "prod"
```

## 📊 Outputs

After deployment, Terraform outputs:
- VPC IDs for each region
- Public EC2 instance IDs and IPs
- Private EC2 instance IDs

## 🔒 Security Best Practices

- ✅ Private subnets have no direct internet access
- ✅ Security groups follow principle of least privilege
- ✅ Private instances only accept traffic from public subnet
- ✅ All resources properly tagged for management
- ✅ State files excluded from version control

## 📝 Modules

### VPC Module
Creates complete networking infrastructure including VPC, subnets, IGW, and route tables.

### Security Group Module
Configurable security groups with dynamic ingress/egress rules.

### EC2 Module
Region-agnostic EC2 instances with automatic AMI selection.

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the MIT License.

## 👤 Author

Created as part of AWS infrastructure learning journey.

---

**Note:** Remember to destroy resources after testing to avoid AWS charges!
