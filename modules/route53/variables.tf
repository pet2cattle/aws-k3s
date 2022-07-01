variable "zones" {
  type    = any
  default = {}
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}