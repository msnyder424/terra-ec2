# BX-Ops-EC2-Terra: Bioinformatics Ops ec2 terraform script

This is a Terraform script to launch an EC2 instance with required dependencies for bioinformatics development.

## Infrastructure Requirements

### Security and Networking
- Create a security group allowing SSH access (port 22) from anywhere (0.0.0.0/22)
- Use the default VPC and subnet for simplicity
- All resources should be tagged appropriately

### Storage
- Use encrypted EBS root volume (64GB, gp3 type)
- No additional volumes required

### Region Support
- Default to us-east-1 but allow user to specify any AWS region
- Automatically adapt to region-specific requirements 

### Terraform Execution Requirements
- Support both direct apply and saved plan workflows
- Provide clear documentation for both development and production use cases
- Include the `-out` option for production deployments to ensure plan consistency
- Recommended execution patterns:
  - **Development**: `terraform apply -var-file=terraform.tfvars`
  - **Production**: `terraform plan -var-file=terraform.tfvars -out=tfplan` then `terraform apply tfplan`

## Host Name

Allow the user to supply a name for the host. This will be used as:
- EC2 instance name tag
- SSH config host alias in connection instructions
- Prefix for AWS resource names (security group, key pair, IAM role)

Include validation to ensure hostname contains only alphanumeric characters and hyphens, and is between 1-63 characters long.

**Note**: The script provides SSH config templates but does not automatically modify the user's SSH config file.

## AWS account
Allow the user to supply an AWS account ID (12-digit number) as input to the script. This is the account in which the ec2 shall be launched.

**AUTHENTICATION REQUIREMENT**: The script must validate that the user is authenticated to the specified AWS account before creating resources. Support only these two authentication methods:

1. **Environment Variables**: User exports AWS credentials
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials
   ```

2. **AWS SSO**: User configures SSO profile
   ```bash
   aws configure sso
   ```

The script must fail with a clear error message if the authenticated account does not match the specified account ID.

## SSH Keys for Access
Allow the user to specify the path to both private key (e.g., {key} or {key}.pem) and public key (e.g., {key}.pub) files. Configure the EC2 instance to allow connections with this key pair. Create an AWS key pair resource using the provided public key.

## AMI
Use the latest stable Ubuntu 22.04 LTS AMI available in AWS. Automatically select the most recent AMI from Canonical (owner ID: 099720109477).

## Instance Type
Default to t2.xlarge, but allow the user to supply any valid instance type as input. Include validation to ensure only valid EC2 instance types are accepted.

## Dependencies to install
### git and ssh keys
Git is already installed in the AWS Ubuntu AMI. 

Allow the user to supply an **optional** path to their git SSH private key. If provided:
1. Copy both {key} and {key}.pub into ~/.ssh in the EC2 instance with proper permissions (600 for private, 644 for public)
2. Configure git to use these SSH keys for push and pull from remote repositories:
```
git config --global core.sshCommand 'ssh -i ~/.ssh/{key}'
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/{key}
```
3. Add SSH agent startup and key addition to ~/.bashrc for persistence

If no git SSH key is provided, skip this configuration entirely.

### conda
install micromamba with these commands:
```
cd ~
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
./bin/micromamba shell init -s bash -r ~/micromamba
```
create this dir structure: `mkdir -p ~/.conda/{envs,pkgs}
create ~/.condarc with the following contents:
```
# .condarc
channels:
  - conda-forge
  - bioconda
show_channel_urls: true
envs_dirs:
  - /home/ubuntu/.conda/envs
pkgs_dirs:
  - /home/ubuntu/.conda/pkgs
```
create an alias in .bashrc: `alias conda="micromamba"`

### docker
install docker and the docker compose plugin. Do not dowload the the `docker-compose` script. We need to be able to run `docker compose` (no dash in command). use this code:
```
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
	"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
configure the docker daemon to allow non root users to run docker:
```
sudo usermod -a -G docker ubuntu
newgrp docker
```

### other dependencies
Install the latest stable versions of the following packages:
- **PHP**: Latest stable from Ubuntu repositories with common extensions (php-cli, php-curl, php-json, php-mbstring, php-xml)
- **Java**: OpenJDK 21 JRE headless version using `sudo apt install openjdk-21-jre-headless`
- **MongoDB**: Community Server for local database development (add official MongoDB repository and install `mongodb-org`)
- **mongosh**: MongoDB Shell for connecting to local and remote databases (install from official MongoDB repository)
- **NVM**: Node Version Manager for managing Node.js versions
- **Node.js**: Use NVM to install latest LTS version with `nvm install --lts`
- **Yarn**: Use npm to install yarn globally: `npm install yarn -g`

Ensure NVM is properly sourced in ~/.bashrc for the ubuntu user.

## Quality of Live env
create ~/.alias with (source the file in ~/.bashrc):
```
# .alias

alias ll="ls -lah"
alias lt="ls -lath"
alias gco="git checkout"
alias gaa="git add -A"
```

create ~/.inputrc with:
```
# .inputrc

"\e[A":history-search-backward
"\e[B":history-search-forward

set colored-stats On
set completion-ignore-case On
set completion-prefix-display-length 3
set mark-symlinked-directories On
set show-all-if-ambiguous On
set show-all-if-unmodified On
set visible-stats On
```

## Build Automation
The script must include VS Code tasks for build automation. Provide tasks for:
- terraform init
- terraform validate  
- terraform plan
- terraform apply
- terraform destroy
- terraform fmt (formatting)
- A combined "build" task that runs: format → init → validate → plan

## Output and Connection Information

Once the ec2 is started, provide comprehensive connection information including:

**Required Output:**
```
EC2 {user supplied host name} is started! 

Connect from a terminal with this command:
ssh -i {user supplied path to SSH keys for access} ubuntu@{public IP address}

Or add this to your ~/.ssh/config (Unix/Linux) or C:\Users\<your-username>\.ssh\config (Windows):

Host {user supplied host name}
    HostName {public IP address}
    User ubuntu
    IdentityFile {user supplied path to SSH keys for access}

Once this entry is added to your .ssh/config you can connect with VSCode with the 'Remote - SSH' extension or from a terminal with this command:
ssh {user supplied host name}

Instance Details:
- Instance ID: {instance_id}
- Instance Type: {instance_type}
- Public IP: {public_ip}
- Private IP: {private_ip}
- Public DNS: {public_dns}
- AWS Region: {aws_region}
- AMI ID: {ami_id}

Post-Installation Steps:
1. After connecting via SSH, run 'source ~/.bashrc' or './refresh_env.sh' to refresh your environment
2. Verify installations:
   - Docker: docker --version && docker compose version
   - Conda: conda --version (alias for micromamba)
   - Node.js: node --version
   - Yarn: yarn --version
   - PHP: php --version
```

## File Structure Requirements
The implementation must include these files:

```
Terraform/ec2/
├── main.tf                     # Main Terraform configuration with provider, EC2, security group
├── variables.tf                # All input variable definitions with validation
├── iam.tf                     # IAM roles and policies
├── outputs.tf                 # Output definitions for connection info
├── user_data.sh               # Template script for dependency installation
├── terraform.tfvars.example   # Sample configuration file
├── README.md                  # Comprehensive user documentation
├── .gitignore                 # Exclude terraform state and sensitive files
└── .vscode/
    └── tasks.json             # VS Code build tasks
```

## Documentation Requirements
Provide comprehensive README.md with:
- High-level description of what the script does
- All user inputs and their descriptions
- Step-by-step usage instructions with both VS Code tasks and command-line options
- Sample terraform.tfvars file with authentication examples
- Authentication setup instructions (environment variables and AWS SSO only)
- Troubleshooting guide for common issues
- File structure overview
- Security features explanation