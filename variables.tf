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
  default = 0
  type    = number
}

variable "k3s_workers_max_capacity" {
  default = 5
  type    = number
}

variable "k3s_workers_min_capacity" {
  default = 0
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