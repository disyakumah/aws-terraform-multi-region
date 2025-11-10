# Usage Guide for Junior Employees

## 🟢 Files You SHOULD Edit (Safe to Modify)

### 1. `Day3/terraform.tfvars` (CREATE THIS FILE)
**Purpose:** Your personal configuration values

**What to do:**
```bash
# Copy the example file
cp Day3/terraform.tfvars.example Day3/terraform.tfvars

# Edit with your values
```

**Example content:**
```hcl
environment = "dev"  # Change to: dev, staging, or prod
```

**Why it's safe:** This file is in `.gitignore` and won't be pushed to GitHub

---

### 2. `Day3/locals.tf` (Only if adding/removing regions)
**Purpose:** Configure which regions to deploy to

**What you can change:**
- Add new regions
- Remove regions you don't need
- Change CIDR blocks
- Change availability zones

**Example - Add a new region:**
```hcl
locals {
  regions = {
    us_west = {
      region           = "us-west-2"
      vpc_cidr         = "10.0.0.0/16"
      public_cidr      = "10.0.1.0/24"
      private_cidr     = "10.0.2.0/24"
      az               = "us-west-2a"
    }
    # ADD YOUR NEW REGION HERE
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

**⚠️ Important:** If you add a region here, you MUST also add it to `main.tf` (see advanced section)

---

### 3. `Day3/variables.tf` (Only to change defaults)
**Purpose:** Define what can be configured

**What you can change:**
- Default values
- Add new variables

**Example - Change default environment:**
```hcl
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"  # Changed from "dev"
}
```

---

## 🔴 Files You Should NOT Edit (Advanced Only)

### ❌ `Day3/main.tf`
**Why:** This is the core orchestration file. Editing this requires understanding Terraform module syntax and provider configuration.

**When to edit:** Only when adding/removing entire regions (requires senior approval)

---

### ❌ `Day3/modules/vpc/main.tf`
**Why:** Core VPC module logic. Breaking this affects all regions.

**When to edit:** Only for infrastructure changes (requires senior approval)

---

### ❌ `Day3/modules/security-group/main.tf`
**Why:** Security group logic. Mistakes can create security vulnerabilities.

**When to edit:** Only for security rule changes (requires security team approval)

---

### ❌ `Day3/modules/ec2/main.tf`
**Why:** EC2 instance configuration. Changes affect all instances.

**When to edit:** Only for instance configuration changes (requires senior approval)

---

### ❌ `Day3/outputs.tf`
**Why:** Defines what information Terraform displays after deployment.

**When to edit:** Only when adding new outputs (requires senior approval)

---

### ❌ Module `variables.tf` and `outputs.tf` files
**Why:** These define module interfaces. Changes can break the entire infrastructure.

**When to edit:** Never without senior review

---

## 📋 Common Tasks for Junior Employees

### Task 1: Deploy to a Different Environment
**Files to edit:** `Day3/terraform.tfvars` (create if doesn't exist)

```hcl
environment = "staging"  # or "prod"
```

Then run:
```bash
cd Day3
terraform plan
terraform apply
```

---

### Task 2: Deploy to Only One Region (Testing)
**Files to edit:** None

**Commands to run:**
```bash
cd Day3
terraform plan -target="module.vpc_us_west" \
               -target="module.sg_public_us_west" \
               -target="module.sg_private_us_west" \
               -target="module.ec2_public_us_west" \
               -target="module.ec2_private_us_west"

terraform apply -target="module.vpc_us_west" \
                -target="module.sg_public_us_west" \
                -target="module.sg_private_us_west" \
                -target="module.ec2_public_us_west" \
                -target="module.ec2_private_us_west"
```

---

### Task 3: Check What Will Be Created
**Files to edit:** None

**Commands to run:**
```bash
cd Day3
terraform plan
```

This shows you what Terraform will create without actually creating it.

---

### Task 4: Destroy Infrastructure (Cleanup)
**Files to edit:** None

**Commands to run:**
```bash
cd Day3
terraform destroy
```

**⚠️ Warning:** This deletes ALL resources. Get approval first!

---

## 🎯 Quick Reference

| Task | File to Edit | Approval Needed |
|------|-------------|-----------------|
| Change environment (dev/prod) | `terraform.tfvars` | ❌ No |
| Deploy infrastructure | None (just run commands) | ✅ Yes |
| Destroy infrastructure | None (just run commands) | ✅ Yes |
| Add a region | `locals.tf` + `main.tf` | ✅ Yes (Senior) |
| Change security rules | `modules/security-group/main.tf` | ✅ Yes (Security Team) |
| Change instance type | `modules/ec2/variables.tf` | ✅ Yes (Senior) |
| Change VPC CIDR | `locals.tf` | ✅ Yes (Network Team) |

---

## 🆘 When to Ask for Help

Ask a senior engineer if you need to:
- ✋ Add or remove a region
- ✋ Change security group rules
- ✋ Modify module files
- ✋ Change networking configuration
- ✋ Deploy to production
- ✋ See any error messages you don't understand

---

## ✅ Safe Commands (Can Run Anytime)

```bash
terraform init       # Initialize/update Terraform
terraform fmt        # Format code nicely
terraform validate   # Check for syntax errors
terraform plan       # Preview changes (doesn't create anything)
git status          # Check what files changed
```

---

## ❌ Dangerous Commands (Need Approval)

```bash
terraform apply     # Creates/modifies infrastructure
terraform destroy   # Deletes infrastructure
git push           # Pushes code to GitHub
```

---

## 📝 Best Practices

1. **Always run `terraform plan` before `terraform apply`**
2. **Never commit `terraform.tfvars` to git** (it's in .gitignore)
3. **Always test in `dev` environment first**
4. **Ask questions if unsure** - better safe than sorry!
5. **Document any changes you make**
6. **Get code review before pushing to GitHub**

---

## 🔒 Security Reminders

- ❌ Never commit AWS credentials to git
- ❌ Never share your `terraform.tfvars` file
- ❌ Never disable security groups without approval
- ✅ Always use least privilege principle
- ✅ Always tag resources properly

---

## 📞 Who to Contact

- **Infrastructure questions:** Senior DevOps Engineer
- **Security questions:** Security Team
- **AWS account issues:** Cloud Administrator
- **Git/GitHub issues:** Development Team Lead

---

**Remember:** When in doubt, ask! It's better to ask than to break production. 🛡️
