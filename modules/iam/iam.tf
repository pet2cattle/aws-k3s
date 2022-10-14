resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "k3s-${var.k3s_cluster_name}-instance-profile"
  role = aws_iam_role.aws_ec2_custom_role.name

  tags = var.tags
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}

resource "aws_iam_role" "aws_ec2_custom_role" {
  name = "k3s-${var.k3s_cluster_name}-role"
  path = "/k3s/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

output "iam_role_arn" {
  value = aws_iam_role.aws_ec2_custom_role.arn
}

# admin policy

data "aws_iam_policy" "AdministratorAccess" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "k3s-admin-policy-attach" {
  count      = var.attach_admin ? 1 : 0
  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = data.aws_iam_policy.AdministratorAccess.arn
}

# AmazonEC2ContainerRegistryReadOnly

data "aws_iam_policy" "AmazonEC2ContainerRegistryReadOnly" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "k3s-AmazonEC2ContainerRegistryReadOnly-policy-attach" {
  count      = var.attach_ecr_ro ? 1 : 0
  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryReadOnly.arn
}