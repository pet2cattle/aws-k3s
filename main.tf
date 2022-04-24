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

  # networking
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids
  keypair_name = module.keypair.name

  # k3s settings
  k3s_token = var.k3s_token
  k3s_cluster_name = var.k3s_cluster_name

  # instance related
  arch = var.arch
  ami_id = var.ami_id
  
  k3s_master_weighted_instance_types = var.k3s_master_weighted_instance_types
  k3s_workers_weighted_instance_types = var.k3s_workers_weighted_instance_types
  
  k3s_workers_desired_capacity = var.k3s_workers_desired_capacity

  tags = var.tags
}