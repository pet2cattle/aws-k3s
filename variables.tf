variable "k3s_cluster_name" {
  type = string
}

variable "k3s_token" {
  type = string
}

variable "arch" {
  type    = string
  default = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.arch)
    error_message = "Invalid architecture: {{ var.arch }}."
  }
}

variable "k3s_master_weighted_instance_types" {
  description = "Master instance types"
  type        = map(string)
  default     = { "m6g.medium" = 1 }
}

variable "k3s_workers_weighted_instance_types" {
  description = "Worker instance types"
  type        = map(string)
  default     = { "m6g.medium" = 1 }
}

variable "ami_id" {
  type = string
  default = ""
}

variable "tags" {
  type = map(string)
  default = {
    infra = "k3s"
    environment = "dev"
  }
}