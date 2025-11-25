terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "observability_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "observability-vpc"
    Environment = var.environment
    Project     = "Jenkins-Observability-Challenge"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.observability_vpc.id

  tags = {
    Name = "observability-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.observability_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "observability-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.observability_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "observability-public-rt"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Groups
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-security-group"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.observability_vpc.id

  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-security-group"
  description = "Security group for Prometheus and Grafana"
  vpc_id      = aws_vpc.observability_vpc.id

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jaeger UI"
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OTel Collector OTLP gRPC"
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "OTel Collector OTLP HTTP"
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-sg"
  }
}

# Allow Jenkins to communicate with monitoring stack
resource "aws_security_group_rule" "jenkins_to_monitoring" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_sg.id
  security_group_id        = aws_security_group.monitoring_sg.id
  description              = "Allow Jenkins to reach monitoring stack"
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = var.jenkins_ami
  instance_type          = var.jenkins_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/scripts/jenkins-setup.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name        = "jenkins-server"
    Environment = var.environment
    Role        = "CI-CD"
  }
}

# Monitoring EC2 Instance (Prometheus + Grafana + Jaeger + OTel Collector)
resource "aws_instance" "monitoring" {
  ami                    = var.monitoring_ami
  instance_type          = var.monitoring_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/scripts/monitoring-setup.sh")

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name        = "monitoring-server"
    Environment = var.environment
    Role        = "Observability"
  }
}

