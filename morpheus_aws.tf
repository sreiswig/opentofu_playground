terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Replace with your desired AWS region
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------

resource "aws_vpc" "morpheus_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "morpheus-vpc"
  }
}

resource "aws_subnet" "public_subnet_az1" {
  vpc_id            = aws_vpc.morpheus_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Replace with your desired AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "morpheus-public-subnet-az1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.morpheus_vpc.id

  tags = {
    Name = "morpheus-internet-gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.morpheus_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "morpheus-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_assoc_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------------------------------------------------------------
# Security Group for Morpheus Instances
# ------------------------------------------------------------------------------

resource "aws_security_group" "morpheus_sg" {
  name_prefix = "morpheus-sg-"
  vpc_id      = aws_vpc.morpheus_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this to your IP range
    description = "SSH access"
  }

  # Add other necessary ingress rules based on your Morpheus application
  # For example, if your application exposes a web interface on port 80 or 443:
  /*
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this
    description = "HTTPS access"
  }
  */

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "morpheus-security-group"
  }
}

# ------------------------------------------------------------------------------
# EC2 Instance for Morpheus (GPU-Enabled)
# ------------------------------------------------------------------------------

resource "aws_instance" "morpheus_instance" {
  ami           = "ami-xxxxxxxxxxxxxxxxx" # Replace with a suitable NVIDIA GPU-enabled AMI
  instance_type = "g4dn.xlarge"        # Choose an appropriate GPU instance type
  subnet_id     = aws_subnet.public_subnet_az1.id
  vpc_security_group_ids = [aws_security_group.morpheus_sg.id]
  key_name      = "your-ec2-key-pair"    # Replace with your EC2 key pair name
  tags = {
    Name = "morpheus-node-1"
  }

  # You might need user_data to install NVIDIA drivers, CUDA, and Morpheus dependencies
  # user_data = <<-EOF
  #   #!/bin/bash
  #   # Install NVIDIA drivers (example - adapt for your AMI and region)
  #   sudo apt update
  #   sudo apt install -y nvidia-driver-535
  #   # Install CUDA (example - adapt for your desired version)
  #   # ...
  #   # Install Morpheus dependencies (example - adapt for your needs)
  #   # ...
  # EOF
}

# ------------------------------------------------------------------------------
# (Optional) S3 Bucket for Data Storage
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "morpheus_data" {
  bucket = "your-morpheus-data-bucket" # Replace with a unique bucket name
  acl    = "private"

  tags = {
    Name = "morpheus-data-bucket"
  }
}

resource "aws_s3_bucket_policy" "morpheus_data_policy" {
  bucket = aws_s3_bucket.morpheus_data.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [aws_instance.morpheus_instance.arn] # Grant access to the Morpheus instance
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.morpheus_data.arn,
          "${aws_s3_bucket.morpheus_data.arn}/*"
        ]
      }
    ]
  })
}
