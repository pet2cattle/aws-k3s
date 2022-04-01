variable "region" {
  type = string
  default = "us-west-2"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "keypair_name" {
  type = string
}

variable "k3s_token" {
  type = string
}

# master ASG 

variable "k3s_master_desired_capacity" {
  default = 1
  type    = number
}

variable "k3s_master_max_capacity" {
  default = 1
  type    = number
}

variable "k3s_master_min_capacity" {
  default = 1
  type    = number
}

variable "master_default_instance_type" {
  default = "m6g.medium"
  type    = string
}

variable "master_instance_types" {
  description = "Master instance types"
  type        = map(string)
  default     = { master_type1 = "m6g.medium" }
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}