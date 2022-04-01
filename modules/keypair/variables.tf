variable "name" {
  type = string
  default = "custom-keypair"
}

variable "pk_path" {
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}