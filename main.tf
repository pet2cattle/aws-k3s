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

module "iam" {
  source = "./modules/iam"

  k3s_cluster_name = var.k3s_cluster_name

  tags = var.tags
}

module "s3" {
  source = "./modules/s3"

  # bucket for backing up the cluster
  k3s_cluster_name = var.k3s_cluster_name

  iam_role_arn = module.iam.iam_role_arn

  # app buckets
  buckets = var.buckets

  tags = var.tags
}
module "route53" {
  source = "./modules/route53"

  zones = var.zones
  
  tags = var.tags
}

module "certs" {
  source = "./modules/certs"

  certs = var.certs
  
  tags = var.tags
}

module "k3s-ec2" {
  source = "./modules/k3s-ec2"

  # networking
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids
  keypair_name = module.keypair.name

  # iam
  instance_profile_name = module.iam.instance_profile_name
  iam_role_arn = module.iam.iam_role_arn

  # k3s settings
  k3s_token = var.k3s_token
  k3s_cluster_name = var.k3s_cluster_name

  # master
  k3s_master_instances = var.k3s_master_instances

  # workers
  k3s_worker_instances = var.k3s_worker_instances

  s3_bucket_name = module.s3.cluster_bucket_name

  tags = var.tags
}