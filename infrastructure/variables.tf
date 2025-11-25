variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "observability-challenge"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "jenkins_ami" {
  description = "AMI ID for Jenkins instance (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS in us-east-1
}

variable "monitoring_ami" {
  description = "AMI ID for monitoring instance (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS in us-east-1
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "monitoring_instance_type" {
  description = "Instance type for monitoring stack"
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

