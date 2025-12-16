# Terra-EC2: Development EC2 Terraform Script

This Terraform script automates the deployment of a fully configured Ubuntu EC2 instance for development work. The instance comes pre-installed with essential development tools including Docker, Conda (via Micromamba), Git, Node.js, PHP, Java, MongoDB, and more.

## High-Level Description

This script creates:
- An EC2 instance with the latest stable Ubuntu AMI
- Security group allowing SSH access
- IAM role for your ec2 that may be modified in order to allow access to specific AWS resources
- Automatic installation of development dependencies via user data script
- SSH key pair configuration for secure access

The instance is configured with all necessary tools for development.

## Prerequisites

1. **Terraform**: Install Terraform >= 1.0
2. **AWS CLI**: Configured with appropriate credentials
3. **SSH Keys**: Have your SSH key pair ready (private and public key files)
4. **Git SSH Keys** (optional): If you want git repository access from the instance

## Required Inputs

### Mandatory Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `hostname` | Name for the host (used as instance name and SSH alias) | `"dev-workstation"` |
| `aws_account_id` | AWS account ID where EC2 will be deployed | `"123456789012"` |
| `ssh_private_key_path` | Path to your SSH private key | `"~/.ssh/id_rsa"` or `"~/.ssh/mykey.pem"` |
| `ssh_public_key_path` | Path to your SSH public key | `"~/.ssh/id_rsa.pub"` or `"~/.ssh/mykey.pub"` |

### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `aws_account_id` | AWS account ID where EC2 will be deployed | **Required** | `"123456789012"` |
| `aws_region` | AWS region for deployment | `"us-east-1"` | `"us-west-2"` |
| `instance_type` | EC2 instance type | `"t2.xlarge"` | `"m5.2xlarge"` |
| `aws_profile` | AWS profile for authentication | `""` | `"my-dev-account"` |
| `assume_role_arn` | IAM role ARN to assume | `""` | `"arn:aws:iam::123456789012:role/TerraformRole"` |
| `git_ssh_private_key_path` | Path to git SSH private key (optional) | `""` | `"~/.ssh/git_rsa"` |
| `ebs_volume_size` | Size of EBS root volume in GB | `64` | `128` |
| `preserve_ebs_on_termination` | Keep EBS volume after instance termination | `false` | `true` |
| `tags` | Additional tags for all resources | `{"CreatedBy": "Terraform", "Purpose": "Development"}` | `{"Environment": "dev", "Team": "engineering"}` |

## AWS Authentication

You need to authenticate to the target AWS account before running Terraform. Choose one of these methods:

### Method 1: Environment Variables
Set your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials
```

### Method 2: AWS SSO
Configure AWS SSO for your organization:

```bash
aws configure sso
# Follow the prompts to set up SSO with your organization
# This will create a profile you can reference
```

Then in your `terraform.tfvars`, you can either:
- Leave `aws_profile` empty to use default credentials (Method 1)
- Set `aws_profile` to your SSO profile name (Method 2)

**Note**: The script will validate that you're authenticated to the correct account before creating resources.

## Usage Instructions

### Step 1: Create Variables File

Create a `terraform.tfvars` file in the `Terraform/ec2/` directory:

`cp Terraform/ec2/terraform.tfvars.example Terraform/ec2/terraform.tfvars`

Edit variables as desired.

**Important**: If you want Git repository access on your EC2 instance, uncomment the `git_ssh_private_key_path` line in your `terraform.tfvars` file and set it to your Git SSH private key path (e.g., `"~/.ssh/id_rsa"`). This will automatically configure Git SSH keys on the instance during deployment.

### Step 2: Deploy the Infrastructure

#### Option A: Using VS Code Tasks (Recommended)

1. Open VS Code in the project root directory
2. Use `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) to open the command palette
3. Type "Tasks: Run Task" and select it
4. Choose "build-terraform-ec2" to run the complete build process

This will automatically run: format → init → validate → plan

#### Option B: Using Command Line

```bash
# Navigate to the terraform directory
cd Terraform/ec2/

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (review what will be created)
terraform plan -var-file=terraform.tfvars

# Apply configuration (create resources)
terraform plan -var-file=terraform.tfvars -out={path to tfplan}
terraform apply {path to tfplan}

### Understanding Terraform Plan Options

**Why use the `-out` option?**

The `-out` option saves the execution plan to a file, ensuring that `terraform apply` executes exactly what was reviewed in the plan. Without it, Terraform generates a new plan during apply, which could differ if resources changed between plan and apply.

**Best Practices:**
- **Development**: Direct apply is fine (`terraform apply -var-file=terraform.tfvars`)
- **Production**: Always save and review plans (`terraform plan -out=tfplan` then `terraform apply tfplan`)
- **Team environments**: Save plans for approval workflows

**Plan file benefits:**
- Guarantees consistency between plan and apply
- Enables approval processes
- Provides audit trails
- Prevents surprises from resource changes
```

### Step 3: Connect to Your Instance

After successful deployment, Terraform will output connection information. You can connect in two ways:

#### Direct SSH Command
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>
```

#### SSH Config Entry (Recommended)
Add this to your `~/.ssh/config` file (or `C:\Users\<username>\.ssh\config` on Windows):

```
Host my-dev-box
    HostName <PUBLIC_IP>
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
```

Then connect with:
```bash
ssh my-dev-box
```

### Step 4: Post-Connection Setup

Once connected to your instance:

```bash
# Refresh your environment to load all installed tools
source ~/.bashrc
# or
./refresh_env.sh

# Verify installations
docker --version && docker compose version
conda --version  # This is an alias for micromamba
node --version
yarn --version
php --version
java --version
mongosh --version
sudo systemctl status mongod  # Check MongoDB status
```

## Sample Commands

### Basic Deployment
```bash
# Minimal terraform.tfvars
echo 'hostname = "dev-box"
ssh_private_key_path = "~/.ssh/id_rsa"
ssh_public_key_path = "~/.ssh/id_rsa.pub"' > terraform.tfvars

# Deploy
terraform init
terraform apply -var-file=terraform.tfvars
```

### Advanced Deployment with Git Keys
```bash
# Advanced terraform.tfvars
echo 'hostname = "dev"
ssh_private_key_path = "~/.ssh/id_rsa"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
instance_type = "m5.xlarge"
aws_region = "us-west-2"
git_ssh_private_key_path = "~/.ssh/github_rsa"' > terraform.tfvars

# Deploy with custom settings
terraform apply -var-file=terraform.tfvars
```

### Cleanup
```bash
# Destroy all resources when done
terraform destroy -var-file=terraform.tfvars
```

## Installed Software

The instance comes pre-configured with:

### Security & Compliance
- **AWS CLI**: For AWS service interactions

### Development Tools
- **Git**: Latest version with SSH key configuration (if provided)
- **Docker & Docker Compose**: Latest stable versions with non-root user access
- **Micromamba**: Lightweight conda alternative with bioconda and conda-forge channels
- **Node.js**: Latest LTS version installed via NVM
- **Yarn**: Package manager for Node.js projects
- **PHP**: Latest stable version with common extensions
- **Java**: OpenJDK 21 JRE headless for Java application support
- **MongoDB**: Community Server for local database development and testing
- **mongosh**: MongoDB Shell for connecting to local and remote databases (including DocumentDB)

### System Configuration
- **Ubuntu 22.04 LTS**: Latest stable AMI
- **64GB EBS Storage**: Encrypted root volume
- **SSH Access**: Configured with your provided keys
- **User Environment**: All tools configured for the `ubuntu` user
- **Quality of Life Enhancements**:
  - Shell aliases (`ll`, `lt`, `gco`, `gaa`)
  - Enhanced bash history search (up/down arrows)
  - Improved tab completion with colors and case-insensitive matching

## AWS Account Considerations
## Security Features

- Encrypted EBS root volume
- Security group restricting access to SSH (port 22) only
- IAM role with minimal required permissions
- SSH key-based authentication (no password access)

## Troubleshooting

### Common Issues

1. **SSH Connection Fails**
   - Verify your SSH key paths are correct
   - Check that your public IP hasn't changed
   - Ensure security group allows your IP

2. **Terraform Plan/Apply Fails**
   - Ensure AWS credentials are configured
   - Check that hostname doesn't conflict with existing resources
   - Verify SSH key files exist at specified paths

### Getting Help

- Check the user data log: `sudo tail -f /var/log/user-data.log`
- Verify AWS credentials: `aws sts get-caller-identity`
- Check Terraform state: `terraform show`

## File Structure

```
Terraform/ec2/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Variable definitions
├── iam.tf              # IAM roles and policies
├── outputs.tf          # Output definitions
├── user_data.sh        # Installation script template
├── terraform.tfvars    # Your variable values (create this)
├── README.md           # This file
└── .vscode/
    └── tasks.json      # VS Code build tasks
```