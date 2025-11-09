# EC2 Module - Input Variables

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID for instance placement"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance"
  type        = list(string)
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to apply to the instance"
  type        = map(string)
  default     = {}
}
