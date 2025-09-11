# main.tf - Main Terraform configuration for Python deployment infrastructure

# Data source for AMIs based on OS type
data "aws_ami" "selected" {
  most_recent = true
  owners      = var.os_type == "ubuntu" ? ["099720109477"] : ["amazon"]

  filter {
    name   = "name"
    values = var.os_type == "ubuntu" ? ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] : ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "python-deployment-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "python-deployment-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "python-deployment-public-subnet"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "python-deployment-public-rt"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "main" {
  name        = "python-deployment-sg"
  description = "Security group for Python deployment instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom application ports"
    from_port   = 8000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "python-deployment-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# IAM Role for EC2 instances (for SSM access)
resource "aws_iam_role" "ec2_ssm" {
  name = "python-deployment-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "python-deployment-ec2-ssm-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "python-deployment-ec2-profile"
  role = aws_iam_role.ec2_ssm.name

  tags = {
    Name        = "python-deployment-ec2-profile"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
  }
}

# EC2 Instances
resource "aws_instance" "python_servers" {
  count = var.instance_count

  ami                    = data.aws_ami.selected.id
  instance_type          = var.instance_type
  key_name              = var.key_pair_name
  subnet_id             = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile  = aws_iam_instance_profile.ec2_profile.name

  user_data = var.os_type == "ubuntu" ? base64encode(local.ubuntu_user_data) : base64encode(local.amazon_linux_user_data)

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name        = "python-server-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "PythonDeployment"
    OS          = var.os_type
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Local variables for user data scripts
locals {
  ubuntu_user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip curl wget unzip
    
    # Install SSM agent (usually pre-installed on Ubuntu AMIs)
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    
    # Install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i amazon-cloudwatch-agent.deb
    
    # Basic Python setup
    python3 -m pip install --upgrade pip
    
    echo "Ubuntu server initialized successfully" > /var/log/user-data.log
  EOF

  amazon_linux_user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip
    
    # SSM agent is pre-installed on Amazon Linux 2
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    
    # Basic Python setup
    python3 -m pip install --upgrade pip
    
    echo "Amazon Linux server initialized successfully" > /var/log/user-data.log
  EOF
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}