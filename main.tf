terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  # If assume_role_arn is provided, assume that role
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Validate we're in the correct AWS account
locals {
  current_account_id = data.aws_caller_identity.current.account_id
  account_validation_message = "ERROR: Currently authenticated to AWS account ${local.current_account_id}, but expected ${var.aws_account_id}. Please check your AWS credentials or profile."
}

# This will cause terraform plan/apply to fail if account IDs don't match
resource "null_resource" "account_validation" {
  count = local.current_account_id != var.aws_account_id ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo '${local.account_validation_message}' && exit 1"
  }
}

# Get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get available VPC and subnet (try default first, fallback to any available)
data "aws_vpcs" "available" {
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "selected" {
  id = data.aws_vpcs.available.ids[0]
}

data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security group for the EC2 instance
resource "aws_security_group" "dev_instance" {
  name_prefix = "${var.hostname}-dev-"
  description = "Security group for ${var.hostname} development instance"
  vpc_id      = data.aws_vpc.selected.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.hostname}-dev-sg"
  })
}

# Key pair for SSH access
resource "aws_key_pair" "dev_instance" {
  key_name   = "${var.hostname}-dev-key"
  public_key = file(var.ssh_public_key_path)

  tags = merge(var.tags, {
    Name = "${var.hostname}-dev-key"
  })
}

# Template for user data script
locals {
  user_data = templatefile("${path.module}/user_data.sh", {
    git_ssh_private_key_content = var.git_ssh_private_key_path != "" ? file(var.git_ssh_private_key_path) : ""
    git_ssh_public_key_content  = var.git_ssh_private_key_path != "" ? file("${var.git_ssh_private_key_path}.pub") : ""
    git_key_name                = var.git_ssh_private_key_path != "" ? basename(var.git_ssh_private_key_path) : ""
    has_git_keys                = var.git_ssh_private_key_path != ""
  })
}

# EC2 Instance
resource "aws_instance" "dev_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.dev_instance.key_name
  vpc_security_group_ids = [aws_security_group.dev_instance.id]
  subnet_id              = data.aws_subnets.available.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.dev_instance.name

  user_data = base64encode(local.user_data)

  # Ensure instance has enough storage
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ebs_volume_size
    encrypted             = true
    delete_on_termination = !var.preserve_ebs_on_termination
    
    tags = merge(var.tags, {
      Name = "${var.hostname}-dev-root"
    })
  }

  tags = merge(var.tags, {
    Name = var.hostname
    Type = "Development"
  })

  # Wait for instance to be ready
  lifecycle {
    create_before_destroy = true
  }
}