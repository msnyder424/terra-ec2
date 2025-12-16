variable "hostname" {
  description = "Name for the host (will be used as instance name and SSH config host alias)"
  type        = string

  validation {
    condition     = length(var.hostname) > 0 && length(var.hostname) <= 63
    error_message = "Hostname must be between 1 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.hostname))
    error_message = "Hostname can only contain alphanumeric characters and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region to deploy the EC2 instance"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID where the EC2 instance will be launched (required for validation)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must be a 12-digit number."
  }
}

variable "aws_profile" {
  description = "AWS profile to use for authentication (OPTIONAL - leave empty to use default credentials)"
  type        = string
  default     = ""
}

variable "assume_role_arn" {
  description = "ARN of IAM role to assume for cross-account access (OPTIONAL)"
  type        = string
  default     = ""
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file (e.g., ~/.ssh/id_rsa or ~/.ssh/mykey.pem)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file (e.g., ~/.ssh/id_rsa.pub or ~/.ssh/mykey.pub)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.xlarge"

  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium", "t2.large", "t2.xlarge", "t2.2xlarge",
      "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge",
      "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge",
      "c5.12xlarge", "c5.18xlarge", "c5.24xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge", "r5.8xlarge",
      "r5.12xlarge", "r5.16xlarge", "r5.24xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a valid EC2 instance type."
  }
}

variable "git_ssh_private_key_path" {
  description = "OPTIONAL path to SSH private key for git operations (e.g., ~/.ssh/git_rsa). Leave empty if not needed."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    CreatedBy = "Terraform"
    Purpose   = "Development"
  }
}

variable "ebs_volume_size" {
  description = "Size of the EBS root volume in GB"
  type        = number
  default     = 64
  
  validation {
    condition     = var.ebs_volume_size >= 8 && var.ebs_volume_size <= 16384
    error_message = "EBS volume size must be between 8 GB and 16,384 GB (16 TB)."
  }
}

variable "preserve_ebs_on_termination" {
  description = "Whether to preserve EBS volume when instance is terminated (WARNING: will continue to incur charges)"
  type        = bool
  default     = false
}