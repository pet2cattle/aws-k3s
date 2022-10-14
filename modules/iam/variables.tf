variable "k3s_cluster_name" {
  type = string
}

variable "access_keys" {
  type = any
  default = {}
}

variable "attach_admin" {
  type    = bool
  default = false
}

variable "attach_ecr_ro" {
  type    = bool
  default = false
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}