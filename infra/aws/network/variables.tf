variable "vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "Public subnet CIDR blocks."
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "Availability zones for each public subnet."
}

variable "map_public_ip_on_launch" {
  type        = bool
  default     = true
  description = "Whether instances launched into public subnets get public IPs."
}

