variable "k3s_cluster_name" {
  type = string
}

variable "access_keys" {
  type = any
  default = {}
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}