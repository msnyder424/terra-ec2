output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.dev_instance.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.dev_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.dev_instance.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.dev_instance.public_dns
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.dev_instance.private_ip}"
}

output "ssh_config_entry" {
  description = "SSH config entry to add to ~/.ssh/config"
  value       = <<-EOT
Host ${var.hostname}
    HostName ${aws_instance.dev_instance.private_ip}
    User ubuntu
    IdentityFile ${var.ssh_private_key_path}
EOT
}

output "connection_info" {
  description = "Complete connection information"
  value       = <<-EOT

================================================================================
EC2 ${var.hostname} is started! 

Connect from a terminal with this command:
ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.dev_instance.private_ip}

Or add this to your ~/.ssh/config (Unix/Linux) or C:\Users\<your-username>\.ssh\config (Windows):

Host ${var.hostname}
    HostName ${aws_instance.dev_instance.private_ip}
    User ubuntu
    IdentityFile ${var.ssh_private_key_path}

Once this entry is added to your .ssh/config you can connect with VSCode with the 'Remote - SSH' extension or from a terminal with this command:
ssh ${var.hostname}

Instance Details:
- Instance ID: ${aws_instance.dev_instance.id}
- Instance Type: ${var.instance_type}
- Public IP: ${aws_instance.dev_instance.public_ip}
- Private IP: ${aws_instance.dev_instance.private_ip}
- Public DNS: ${aws_instance.dev_instance.public_dns}
- AWS Region: ${var.aws_region}
- AMI ID: ${aws_instance.dev_instance.ami}

Post-Installation Steps:
1. After connecting via SSH, run 'source ~/.bashrc' or './refresh_env.sh' to refresh your environment
2. Verify installations:
   - Docker: docker --version && docker compose version
   - Conda: conda --version (alias for micromamba)
   - Node.js: node --version
   - Yarn: yarn --version
   - PHP: php --version
3. Test Quality of Life features:
   - Try aliases: ll (detailed listing), gco <branch> (git checkout), gaa (git add all)
   - Use up/down arrows for enhanced history search
   - Press Tab for improved completion with colors

================================================================================
EOT
}