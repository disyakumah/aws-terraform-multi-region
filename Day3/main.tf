# Root Module - Multi-Region AWS Infrastructure
# This configuration deploys VPC, Security Groups, and EC2 instances across multiple regions

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS providers for each region
provider "aws" {
  alias  = "us_west"
  region = local.regions.us_west.region
}

provider "aws" {
  alias  = "us_east"
  region = local.regions.us_east.region
}

provider "aws" {
  alias  = "eu_west"
  region = local.regions.eu_west.region
}

# Deploy VPC in us-west-2
module "vpc_us_west" {
  source = "./modules/vpc"

  providers = {
    aws = aws.us_west
  }

  vpc_cidr            = local.regions.us_west.vpc_cidr
  public_subnet_cidr  = local.regions.us_west.public_cidr
  private_subnet_cidr = local.regions.us_west.private_cidr
  availability_zone   = local.regions.us_west.az
  region              = local.regions.us_west.region
  environment         = var.environment
}

# Deploy VPC in us-east-1
module "vpc_us_east" {
  source = "./modules/vpc"

  providers = {
    aws = aws.us_east
  }

  vpc_cidr            = local.regions.us_east.vpc_cidr
  public_subnet_cidr  = local.regions.us_east.public_cidr
  private_subnet_cidr = local.regions.us_east.private_cidr
  availability_zone   = local.regions.us_east.az
  region              = local.regions.us_east.region
  environment         = var.environment
}

# Deploy VPC in eu-west-1
module "vpc_eu_west" {
  source = "./modules/vpc"

  providers = {
    aws = aws.eu_west
  }

  vpc_cidr            = local.regions.eu_west.vpc_cidr
  public_subnet_cidr  = local.regions.eu_west.public_cidr
  private_subnet_cidr = local.regions.eu_west.private_cidr
  availability_zone   = local.regions.eu_west.az
  region              = local.regions.eu_west.region
  environment         = var.environment
}

# Security Groups for us-west-2
module "sg_public_us_west" {
  source = "./modules/security-group"

  providers = {
    aws = aws.us_west
  }

  vpc_id      = module.vpc_us_west.vpc_id
  name        = "${var.environment}-public-sg-us-west-2"
  description = "Security group for public instances - allows HTTP/HTTPS"

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from internet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    Name        = "${var.environment}-public-sg-us-west-2"
    Environment = var.environment
    Region      = "us-west-2"
  }
}

module "sg_private_us_west" {
  source = "./modules/security-group"

  providers = {
    aws = aws.us_west
  }

  vpc_id      = module.vpc_us_west.vpc_id
  name        = "${var.environment}-private-sg-us-west-2"
  description = "Security group for private instances - allows traffic from public subnet only"

  ingress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.vpc_us_west.public_subnet_cidr]
      description = "Allow all traffic from public subnet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    Name        = "${var.environment}-private-sg-us-west-2"
    Environment = var.environment
    Region      = "us-west-2"
  }
}

# Security Groups for us-east-1
module "sg_public_us_east" {
  source = "./modules/security-group"

  providers = {
    aws = aws.us_east
  }

  vpc_id      = module.vpc_us_east.vpc_id
  name        = "${var.environment}-public-sg-us-east-1"
  description = "Security group for public instances - allows HTTP/HTTPS"

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from internet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    Name        = "${var.environment}-public-sg-us-east-1"
    Environment = var.environment
    Region      = "us-east-1"
  }
}

module "sg_private_us_east" {
  source = "./modules/security-group"

  providers = {
    aws = aws.us_east
  }

  vpc_id      = module.vpc_us_east.vpc_id
  name        = "${var.environment}-private-sg-us-east-1"
  description = "Security group for private instances - allows traffic from public subnet only"

  ingress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.vpc_us_east.public_subnet_cidr]
      description = "Allow all traffic from public subnet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    Name        = "${var.environment}-private-sg-us-east-1"
    Environment = var.environment
    Region      = "us-east-1"
  }
}

# Security Groups for eu-west-1
module "sg_public_eu_west" {
  source = "./modules/security-group"

  providers = {
    aws = aws.eu_west
  }

  vpc_id      = module.vpc_eu_west.vpc_id
  name        = "${var.environment}-public-sg-eu-west-1"
  description = "Security group for public instances - allows HTTP/HTTPS"

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from internet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    Name        = "${var.environment}-public-sg-eu-west-1"
    Environment = var.environment
    Region      = "eu-west-1"
  }
}

module "sg_private_eu_west" {
  source = "./modules/security-group"

  providers = {
    aws = aws.eu_west
  }

  vpc_id      = module.vpc_eu_west.vpc_id
  name        = "${var.environment}-private-sg-eu-west-1"
  description = "Security group for private instances - allows traffic from public subnet only"

  ingress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.vpc_eu_west.public_subnet_cidr]
      description = "Allow all traffic from public subnet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    Name        = "${var.environment}-private-sg-eu-west-1"
    Environment = var.environment
    Region      = "eu-west-1"
  }
}

# EC2 Instances for us-west-2
module "ec2_public_us_west" {
  source = "./modules/ec2"

  providers = {
    aws = aws.us_west
  }

  instance_type      = "t2.micro"
  subnet_id          = module.vpc_us_west.public_subnet_id
  security_group_ids = [module.sg_public_us_west.security_group_id]
  instance_name      = "${var.environment}-public-instance-us-west-2"

  additional_tags = {
    Environment = var.environment
    Region      = "us-west-2"
    Type        = "public"
  }
}

module "ec2_private_us_west" {
  source = "./modules/ec2"

  providers = {
    aws = aws.us_west
  }

  instance_type      = "t2.micro"
  subnet_id          = module.vpc_us_west.private_subnet_id
  security_group_ids = [module.sg_private_us_west.security_group_id]
  instance_name      = "${var.environment}-private-instance-us-west-2"

  additional_tags = {
    Environment = var.environment
    Region      = "us-west-2"
    Type        = "private"
  }
}

# EC2 Instances for us-east-1
module "ec2_public_us_east" {
  source = "./modules/ec2"

  providers = {
    aws = aws.us_east
  }

  instance_type      = "t2.micro"
  subnet_id          = module.vpc_us_east.public_subnet_id
  security_group_ids = [module.sg_public_us_east.security_group_id]
  instance_name      = "${var.environment}-public-instance-us-east-1"

  additional_tags = {
    Environment = var.environment
    Region      = "us-east-1"
    Type        = "public"
  }
}

module "ec2_private_us_east" {
  source = "./modules/ec2"

  providers = {
    aws = aws.us_east
  }

  instance_type      = "t2.micro"
  subnet_id          = module.vpc_us_east.private_subnet_id
  security_group_ids = [module.sg_private_us_east.security_group_id]
  instance_name      = "${var.environment}-private-instance-us-east-1"

  additional_tags = {
    Environment = var.environment
    Region      = "us-east-1"
    Type        = "private"
  }
}

# EC2 Instances for eu-west-1
module "ec2_public_eu_west" {
  source = "./modules/ec2"

  providers = {
    aws = aws.eu_west
  }

  instance_type      = "t2.micro"
  subnet_id          = module.vpc_eu_west.public_subnet_id
  security_group_ids = [module.sg_public_eu_west.security_group_id]
  instance_name      = "${var.environment}-public-instance-eu-west-1"

  additional_tags = {
    Environment = var.environment
    Region      = "eu-west-1"
    Type        = "public"
  }
}

module "ec2_private_eu_west" {
  source = "./modules/ec2"

  providers = {
    aws = aws.eu_west
  }

  instance_type      = "t2.micro"
  subnet_id          = module.vpc_eu_west.private_subnet_id
  security_group_ids = [module.sg_private_eu_west.security_group_id]
  instance_name      = "${var.environment}-private-instance-eu-west-1"

  additional_tags = {
    Environment = var.environment
    Region      = "eu-west-1"
    Type        = "private"
  }
}
