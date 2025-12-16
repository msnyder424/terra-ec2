#!/bin/bash

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user data script at $(date)"

# Update system
apt-get update -y

# Install basic tools
apt-get install -y curl wget unzip software-properties-common

# Install AWS CLI (using snap as specified)
snap install aws-cli --classic

# Get instance metadata
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

echo "=== Setting up Git and SSH Keys ==="

# Git is already installed in Ubuntu AMI, but let's ensure it's the latest
apt-get install -y git

%{ if has_git_keys }
# Setup SSH keys for git (if provided)
sudo -u ubuntu mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Write the private key
cat > /home/ubuntu/.ssh/${git_key_name} << 'EOF'
${git_ssh_private_key_content}
EOF

# Write the public key
cat > /home/ubuntu/.ssh/${git_key_name}.pub << 'EOF'
${git_ssh_public_key_content}
EOF

# Set proper permissions
chmod 600 /home/ubuntu/.ssh/${git_key_name}
chmod 644 /home/ubuntu/.ssh/${git_key_name}.pub
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Configure git to use these SSH keys
sudo -u ubuntu git config --global core.sshCommand 'ssh -i ~/.ssh/${git_key_name}'

# Start SSH agent and add key (add to .bashrc for persistence)
echo 'eval "$(ssh-agent -s)"' >> /home/ubuntu/.bashrc
echo 'ssh-add ~/.ssh/${git_key_name}' >> /home/ubuntu/.bashrc

echo "Git SSH keys configured"
%{ else }
echo "No git SSH keys provided, skipping git SSH configuration"
%{ endif }

echo "=== Installing Micromamba (Conda alternative) ==="

# Install micromamba as ubuntu user
sudo -u ubuntu bash << 'EOL'
cd /home/ubuntu
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
./bin/micromamba shell init -s bash -r /home/ubuntu/micromamba

# Create conda directories
mkdir -p /home/ubuntu/.conda/{envs,pkgs}

# Create .condarc
cat > /home/ubuntu/.condarc << 'EOF'
# .condarc
channels:
  - conda-forge
  - bioconda
show_channel_urls: true
envs_dirs:
  - /home/ubuntu/.conda/envs
pkgs_dirs:
  - /home/ubuntu/.conda/pkgs
EOF

# Add conda alias to .bashrc
echo 'alias conda="micromamba"' >> /home/ubuntu/.bashrc
EOL

echo "Micromamba installation completed"

echo "=== Installing Docker ==="

# Install Docker and Docker Compose plugin
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure docker for non-root user
usermod -a -G docker ubuntu

echo "Docker installation completed"

echo "=== Installing PHP ==="

# Install PHP (latest stable from Ubuntu repositories)
apt-get install -y php php-cli php-common php-curl php-json php-mbstring php-xml

echo "PHP installation completed"

echo "=== Installing Java ==="

# Install OpenJDK 21 JRE headless
apt-get install -y openjdk-21-jre-headless

echo "Java installation completed"

echo "=== Installing MongoDB and mongosh ==="

# Import MongoDB public GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

# Create list file for MongoDB
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package database
apt-get update

# Install MongoDB
apt-get install -y mongodb-org

# Install mongosh (MongoDB Shell)
apt-get install -y mongodb-mongosh

# Enable and start MongoDB service
systemctl enable mongod
systemctl start mongod

# Create MongoDB data directory with proper permissions
mkdir -p /var/lib/mongodb
chown mongodb:mongodb /var/lib/mongodb

echo "MongoDB and mongosh installation completed"

echo "=== Installing NVM, Node.js, and Yarn ==="

# Install NVM as ubuntu user
sudo -u ubuntu bash << 'EOL'
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Source NVM
export NVM_DIR="/home/ubuntu/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Install latest LTS Node.js
nvm install --lts
nvm use --lts

# Install Yarn globally
npm install -g yarn

# Add NVM sourcing to .bashrc if not already there
if ! grep -q 'NVM_DIR' /home/ubuntu/.bashrc; then
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/ubuntu/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/ubuntu/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/ubuntu/.bashrc
fi
EOL

echo "NVM, Node.js, and Yarn installation completed"

echo "=== Quality of Life Environment Setup ==="

# Create ~/.alias file
sudo -u ubuntu bash << 'EOL'
cat > /home/ubuntu/.alias << 'EOF'
# .alias

alias ll="ls -lah"
alias lt="ls -lath"
alias gco="git checkout"
alias gaa="git add -A"
EOF
EOL

# Create ~/.inputrc file
sudo -u ubuntu bash << 'EOL'
cat > /home/ubuntu/.inputrc << 'EOF'
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
EOF
EOL

# Source the alias file in .bashrc
echo 'source ~/.alias' >> /home/ubuntu/.bashrc

echo "Quality of Life environment setup completed"

echo "=== Final Setup ==="

# Ensure ubuntu user owns their home directory
chown -R ubuntu:ubuntu /home/ubuntu

# Set up a convenient script to refresh environment
cat > /home/ubuntu/refresh_env.sh << 'EOF'
#!/bin/bash
# Refresh environment after installation
source ~/.bashrc
eval "$(ssh-agent -s)"
%{ if has_git_keys }
ssh-add ~/.ssh/${git_key_name}
%{ endif }
newgrp docker
EOF

chmod +x /home/ubuntu/refresh_env.sh
chown ubuntu:ubuntu /home/ubuntu/refresh_env.sh

echo "User data script completed at $(date)"
echo "All installations finished successfully!"
echo "Run 'source ~/.bashrc' or './refresh_env.sh' to refresh your environment"