variable "k3s_token" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    infra = "k3s"
    environment = "dev"
  }
}