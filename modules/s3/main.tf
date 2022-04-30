resource "aws_s3_bucket" "k3s_bucket" {
  bucket = "k3s-${var.k3s_cluster_name}"

  tags = var.tags
}

resource "aws_s3_bucket_acl" "k3s_bucket" {
  bucket = aws_s3_bucket.k3s_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "k3s_allow_access_bucket" {
  bucket = aws_s3_bucket.k3s_bucket.id
  policy = data.aws_iam_policy_document.k3s_allow_access_bucket.json
}

data "aws_iam_policy_document" "k3s_allow_access_bucket" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.iam_role_arn]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.k3s_bucket.arn,
      "${aws_s3_bucket.k3s_bucket.arn}/*",
    ]
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.k3s_bucket.bucket
}