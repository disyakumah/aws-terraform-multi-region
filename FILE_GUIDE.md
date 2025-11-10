# File Editing Guide - Quick Reference

## 🎯 Simple Rule: Edit Only Configuration, Not Code

```
📁 Day3/
├── 🟢 terraform.tfvars          ← SAFE: Your personal settings
├── 🟡 locals.tf                 ← CAUTION: Region configuration (ask first)
├── 🟡 variables.tf              ← CAUTION: Default values (ask first)
├── 🔴 main.tf                   ← DANGER: Core logic (senior only)
├── 🔴 outputs.tf                ← DANGER: Output config (senior only)
├── 📘 terraform.tfvars.example  ← READ ONLY: Example file
├── 📘 README.md                 ← READ ONLY: Documentation
└── 📁 modules/
    ├── 📁 vpc/
    │   ├── 🔴 main.tf           ← DANGER: VPC logic (senior only)
    │   ├── 🔴 variables.tf      ← DANGER: Module interface (senior only)
    │   └── 🔴 outputs.tf        ← DANGER: Module outputs (senior only)
    ├── 📁 security-group/
    │   ├── 🔴 main.tf           ← DANGER: Security rules (security team only)
    │   ├── 🔴 variables.tf      ← DANGER: Module interface (senior only)
    │   └── 🔴 outputs.tf        ← DANGER: Module outputs (senior only)
    └── 📁 ec2/
        ├── 🔴 main.tf           ← DANGER: Instance config (senior only)
        ├── 🔴 data.tf           ← DANGER: AMI lookup (senior only)
        ├── 🔴 variables.tf      ← DANGER: Module interface (senior only)
        └── 🔴 outputs.tf        ← DANGER: Module outputs (senior only)
```

---

## Legend

| Symbol | Meaning | Can I Edit? |
|--------|---------|-------------|
| 🟢 | **SAFE** - Edit freely | ✅ Yes |
| 🟡 | **CAUTION** - Ask first | ⚠️ With approval |
| 🔴 | **DANGER** - Senior only | ❌ No |
| 📘 | **READ ONLY** - Don't edit | 👀 View only |

---

## For Junior Employees: Your Workflow

### Step 1: Create Your Config File
```bash
cd Day3
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Edit Your Settings (SAFE)
Edit `terraform.tfvars`:
```hcl
environment = "dev"  # Change this as needed
```

### Step 3: Deploy
```bash
terraform init
terraform plan    # Preview changes
terraform apply   # Deploy (get approval first!)
```

---

## What Each File Does (Simple Explanation)

### 🟢 `terraform.tfvars` (YOU EDIT THIS)
**What it is:** Your personal settings  
**Example:** Which environment (dev/staging/prod)  
**Why safe:** Doesn't affect code logic, just values

---

### 🟡 `locals.tf` (ASK BEFORE EDITING)
**What it is:** List of regions to deploy to  
**Example:** us-west-2, us-east-1, eu-west-1  
**Why caution:** Adding regions costs money

---

### 🟡 `variables.tf` (ASK BEFORE EDITING)
**What it is:** What settings are available  
**Example:** Default environment name  
**Why caution:** Changes affect everyone

---

### 🔴 `main.tf` (DON'T TOUCH)
**What it is:** The "brain" - connects everything  
**Example:** Calls VPC module, EC2 module, etc.  
**Why dangerous:** Breaking this breaks everything

---

### 🔴 `modules/*/main.tf` (DON'T TOUCH)
**What it is:** The actual infrastructure code  
**Example:** How to create a VPC, security group, EC2  
**Why dangerous:** Mistakes create security issues or outages

---

## Real-World Scenarios

### Scenario 1: "I want to deploy to staging"
**What to edit:** `terraform.tfvars`
```hcl
environment = "staging"
```
**Approval needed:** No (but get approval to run `terraform apply`)

---

### Scenario 2: "I want to add ap-south-1 region"
**What to edit:** `locals.tf` (add region) + `main.tf` (add module calls)
**Approval needed:** ✅ YES - Senior engineer must review

---

### Scenario 3: "I want to allow SSH access"
**What to edit:** `modules/security-group/main.tf`
**Approval needed:** ✅ YES - Security team must review

---

### Scenario 4: "I want to use t3.small instead of t2.micro"
**What to edit:** `modules/ec2/variables.tf` (change default)
**Approval needed:** ✅ YES - Senior engineer (costs more money)

---

## 🚨 Emergency: I Broke Something!

### If you edited a 🔴 file and things broke:

1. **Don't panic!**
2. **Don't run `terraform apply`**
3. **Revert your changes:**
   ```bash
   git checkout -- filename.tf
   ```
4. **Tell your senior engineer immediately**

---

## ✅ Safe Daily Tasks

These you can do without asking:

1. **Check status:**
   ```bash
   terraform plan
   ```

2. **Format code:**
   ```bash
   terraform fmt
   ```

3. **Validate syntax:**
   ```bash
   terraform validate
   ```

4. **Check git status:**
   ```bash
   git status
   ```

---

## 📚 Learning Path

### Week 1-2: Observer
- Read all files
- Run `terraform plan`
- Understand what each module does

### Week 3-4: Configuration
- Edit `terraform.tfvars`
- Deploy to dev environment (with supervision)

### Month 2-3: Regions
- Learn to add regions in `locals.tf`
- Understand CIDR blocks

### Month 4+: Modules
- Start learning module internals
- Make small changes with review

---

## 💡 Pro Tips

1. **Always work in a branch:**
   ```bash
   git checkout -b my-feature
   ```

2. **Test in dev first:**
   ```hcl
   environment = "dev"  # Always test here first
   ```

3. **Use terraform plan:**
   ```bash
   terraform plan > plan.txt  # Save plan for review
   ```

4. **Document your changes:**
   ```bash
   git commit -m "Changed environment to staging for testing"
   ```

---

## 🎓 Want to Learn More?

- **Terraform Basics:** https://learn.hashicorp.com/terraform
- **AWS VPC:** https://docs.aws.amazon.com/vpc/
- **Git Basics:** https://git-scm.com/book/en/v2

---

**Remember: It's okay to ask questions! Everyone was a beginner once.** 🌱
