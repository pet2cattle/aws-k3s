variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}

resource "aws_eip" "eip" {
  vpc = true

  tags = var.tags
}