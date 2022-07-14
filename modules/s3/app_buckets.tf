resource "aws_s3_bucket" "app_buckets" {
  for_each = var.buckets

  bucket = each.key

  tags = var.tags
}

resource "aws_s3_bucket_acl" "app_buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.app_buckets[each.key].id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "app_buckets_allow_access_bucket" {
  for_each = var.buckets

  bucket = aws_s3_bucket.app_buckets[each.key].id
  policy = data.aws_iam_policy_document.app_buckets_allow_access_bucket[each.key].json
}

data "aws_iam_policy_document" "app_buckets_allow_access_bucket" {
  for_each = var.buckets

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = try([var.users[each.key].arn], [])
    }

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.app_buckets[each.key].arn,
      "${aws_s3_bucket.app_buckets[each.key].arn}/*",
    ]
  }
}