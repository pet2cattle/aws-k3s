resource "aws_iam_user" "ak" {
  for_each = var.access_keys

  name = each.key
  path = try(each.value.iam_path, "/system/")

  tags = var.tags
}

resource "aws_iam_access_key" "ak" {
  for_each = var.access_keys

  user = aws_iam_user.ak[each.key].name
}

output "secrets" {
  value = aws_iam_access_key.ak
}

output "users" {
  value = aws_iam_user.ak
}