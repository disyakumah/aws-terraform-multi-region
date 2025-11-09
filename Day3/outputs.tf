# Root Module - Outputs
# Outputs from all regions

# US-West-2 Outputs
output "us_west_vpc_id" {
  description = "VPC ID in us-west-2"
  value       = module.vpc_us_west.vpc_id
}

output "us_west_public_instance_id" {
  description = "Public EC2 instance ID in us-west-2"
  value       = module.ec2_public_us_west.instance_id
}

output "us_west_public_instance_ip" {
  description = "Public EC2 instance public IP in us-west-2"
  value       = module.ec2_public_us_west.public_ip
}

output "us_west_private_instance_id" {
  description = "Private EC2 instance ID in us-west-2"
  value       = module.ec2_private_us_west.instance_id
}

# US-East-1 Outputs
output "us_east_vpc_id" {
  description = "VPC ID in us-east-1"
  value       = module.vpc_us_east.vpc_id
}

output "us_east_public_instance_id" {
  description = "Public EC2 instance ID in us-east-1"
  value       = module.ec2_public_us_east.instance_id
}

output "us_east_public_instance_ip" {
  description = "Public EC2 instance public IP in us-east-1"
  value       = module.ec2_public_us_east.public_ip
}

output "us_east_private_instance_id" {
  description = "Private EC2 instance ID in us-east-1"
  value       = module.ec2_private_us_east.instance_id
}

# EU-West-1 Outputs
output "eu_west_vpc_id" {
  description = "VPC ID in eu-west-1"
  value       = module.vpc_eu_west.vpc_id
}

output "eu_west_public_instance_id" {
  description = "Public EC2 instance ID in eu-west-1"
  value       = module.ec2_public_eu_west.instance_id
}

output "eu_west_public_instance_ip" {
  description = "Public EC2 instance public IP in eu-west-1"
  value       = module.ec2_public_eu_west.public_ip
}

output "eu_west_private_instance_id" {
  description = "Private EC2 instance ID in eu-west-1"
  value       = module.ec2_private_eu_west.instance_id
}
