resource "aws_vpc" "server_vpc" {
  cidr_block           = var.main_vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

resource "aws_subnet" "vpc_subnets" {
  for_each          = toset(var.az_subnets)

  cidr_block        = cidrsubnet(var.main_vpc_cidr_block, 8, index(var.az_subnets, each.value))
  vpc_id            = aws_vpc.server_vpc.id
  availability_zone = each.value

  tags = var.tags
}

output "vpc_id" {
  value = aws_vpc.server_vpc.id
}
 
output "subnet_ids" {
  value = [ for each in aws_subnet.vpc_subnets : each.id ]
}