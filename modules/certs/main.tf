resource "aws_acm_certificate" "certs" {
  for_each = var.certs

  domain_name       = each.key
  validation_method = try(each.value.validation_method, "DNS")

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}