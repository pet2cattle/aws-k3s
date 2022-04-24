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

variable "k3s_cluster_name" {
  type = string
}

variable "arch" {
  type    = string
  default = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.arch)
    error_message = "Invalid architecture: {{ var.arch }} Valid values are: arm64, x86_64."
  }

}

variable "ami_id" {
  type = string
  default = ""
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

variable "k3s_master_weighted_instance_types" {
  description = "Master instance types"
  type        = map(string)
  default     = { "m6g.medium" = 1 }
}

variable "k3s_master_on_demand_base_capacity" {
  type    = number
  default = 0
}

variable "k3s_master_on_demand_percentage_above_base_capacity" {
  type    = number
  default = 0
}

# workers ASG

variable "k3s_workers_desired_capacity" {
  default = 1
  type    = number
}

variable "k3s_workers_max_capacity" {
  default = 5
  type    = number
}

variable "k3s_workers_min_capacity" {
  default = 1
  type    = number
}

variable "k3s_workers_weighted_instance_types" {
  description = "Worker instance types"
  type        = map(string)
  default     = { "m6g.medium" = 1 }
}

variable "k3s_workers_on_demand_base_capacity" {
  type    = number
  default = 0
}

variable "k3s_workers_on_demand_percentage_above_base_capacity" {
  type    = number
  default = 0
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}