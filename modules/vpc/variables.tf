variable "region" {
  type = string
  default = "us-west-2"
}

variable "main_vpc_cidr_block" {
  type = string
  default = "10.12.0.0/16"
}

variable "az_subnets" {
  description = "List of AZs to use"
  type        = map(string)
  default = {
    us-west-2a = "10.12.100.0/24",
    us-west-2b = "10.12.101.0/24",
    us-west-2c = "10.12.102.0/24"
  }
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}