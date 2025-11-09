# Root Module - Local Values
# Multi-region configuration

locals {
  regions = {
    us_west = {
      region       = "us-west-2"
      vpc_cidr     = "10.0.0.0/16"
      public_cidr  = "10.0.1.0/24"
      private_cidr = "10.0.2.0/24"
      az           = "us-west-2a"
    }
    us_east = {
      region       = "us-east-1"
      vpc_cidr     = "10.1.0.0/16"
      public_cidr  = "10.1.1.0/24"
      private_cidr = "10.1.2.0/24"
      az           = "us-east-1a"
    }
    eu_west = {
      region       = "eu-west-1"
      vpc_cidr     = "10.2.0.0/16"
      public_cidr  = "10.2.1.0/24"
      private_cidr = "10.2.2.0/24"
      az           = "eu-west-1a"
    }
  }
}
