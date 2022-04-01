variable "region" {
  type = string
  default = "us-west-2"
}

variable "instance_types" {
  description = "List of instance types to use"
  type        = map(string)
  default = {
    asg_instance_type_1 = "t3.large"
    asg_instance_type_2 = "t2.large"
    asg_instance_type_3 = "m4.large"
    asg_instance_type_4 = "t3a.large"
  }
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}