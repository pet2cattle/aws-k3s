resource "aws_vpc" "server_vpc" {
  cidr_block           = var.main_vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

resource "aws_subnet" "vpc_subnets" {
  for_each          = toset(var.az_subnets)

  cidr_block        = cidrsubnet(var.main_vpc_cidr_block, 2, index(var.az_subnets, each.value))
  vpc_id            = aws_vpc.server_vpc.id
  availability_zone = each.value

  map_public_ip_on_launch = true

  tags = merge(
                var.tags,
                {
                  "kubernetes.io/cluster/default" = "shared"
                  "kubernetes.io/role/elb" = "1"
                },
                try({"Name" = var.appname }, {})
              )
}

resource "aws_db_subnet_group" "subnet_group" {
  name       = var.appname
  subnet_ids = [ for each in aws_subnet.vpc_subnets : each.id ]

  tags = merge(
                var.tags,
                try({"Name" = var.appname }, {})
              )
}


resource "aws_internet_gateway" "inet_gw" {
  vpc_id = aws_vpc.server_vpc.id

  tags = var.tags
}

resource "aws_route_table" "route_table_servers" {
  vpc_id = aws_vpc.server_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.inet_gw.id
  }

  tags = var.tags
}

resource "aws_main_route_table_association" "vpc_route_servers" {
  vpc_id         = aws_vpc.server_vpc.id
  route_table_id = aws_route_table.route_table_servers.id
}

output "vpc_id" {
  value = aws_vpc.server_vpc.id
}
 
output "subnet_ids" {
  value = [ for each in aws_subnet.vpc_subnets : each.id ]
}

output "main_vpc_cidr_block" {
  value = var.main_vpc_cidr_block  
}