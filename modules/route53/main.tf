resource "aws_route53_zone" "zones" {
  for_each = var.zones
  name = each.key

  tags = var.tags
}