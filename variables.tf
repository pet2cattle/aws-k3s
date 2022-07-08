# tags

variable "tags" {
  type = map(string)
  default = {
    infra = "k3s"
    environment = "dev"
  }
}

# app

variable "k3s_cluster_name" {
  type = string
}

variable "k3s_token" {
  type = string
}

# instances

variable "ami_id" {
  type = string
  default = ""
}

# master ASG 

variable "k3s_master_instances" {
  type    = any
  default = {}
}

# workers ASG

variable "k3s_worker_instances" {
  type    = any
  default = {}
}

# ACM certs

variable "certs" {
  type    = any
  default = {}
}

# route53 zones

variable "zones" {
  type    = any
  default = {}
}

# app buckets

variable "buckets" {
  type    = any
  default = {}
}