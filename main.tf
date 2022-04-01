terraform {
  required_version = ">= 1.0.8"
}

provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source = "./modules/vpc"

  tags = var.tags
}

module "keypair" {
  source = "./modules/keypair"

  name = "k3s-keypair"
  tags = var.tags
}

module "k3s-ec2" {
  source = "./modules/k3s-ec2"

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids
  keypair_name = module.keypair.name

  k3s_token = var.k3s_token

  tags = var.tags
}