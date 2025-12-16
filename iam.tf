# IAM role for EC2 instance
resource "aws_iam_role" "dev_instance" {
  name  = "${var.hostname}-dev-role"

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

  tags = merge(var.tags, {
    Name = "${var.hostname}-dev-role"
  })
}

# IAM instance profile
resource "aws_iam_instance_profile" "dev_instance" {
  name = "${var.hostname}-dev-profile"
  role = aws_iam_role.dev_instance.name

  tags = merge(var.tags, {
    Name = "${var.hostname}-dev-profile"
  })
}