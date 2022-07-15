variable "appname" {
  type = string
  default = null
}

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
  type        = list(string)
  default = [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c",
    "us-west-2d"
  ]
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}