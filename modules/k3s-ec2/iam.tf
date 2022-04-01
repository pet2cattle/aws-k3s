resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = var.default_instance_profile_name
  role = aws_iam_role.aws_ec2_custom_role.name

  tags = var.tags
}

resource "aws_iam_role" "aws_ec2_custom_role" {
  name = var.default_iam_role

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

resource "aws_iam_role_policy_attachment" "attach_ec2_ro_policy" {
  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ReadOnlyAccess.arn
}