variable "k3s_cluster_name" {
  type = string
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}