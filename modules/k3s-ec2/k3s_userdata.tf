data "aws_caller_identity" "current" {}

locals {
  template_vars = { 
                    K3S_TOKEN           = var.k3s_token, 
                    K3S_CLUSTERNAME     = var.k3s_cluster_name
                    REGION              = var.region
                    K3S_BUCKET          = var.s3_bucket_name
                    K3S_BACKUP_PREFIX   = "${var.s3_backup_prefix}/${var.k3s_cluster_name}"
                    MAIN_VPC_CIDR_BLOCK = var.main_vpc_cidr_block
                    ACCOUNT_ID          = data.aws_caller_identity.current.account_id
                    IAM_ROLE            = var.iam_role_arn
                  }
}

data "template_cloudinit_config" "k3s_master_ud" {
  for_each = var.k3s_master_instances

  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/userdata/init.cfg", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/userdata/install_k3s.sh",  merge(local.template_vars,  {
                                                                                                  TAINT             = try(each.value.taint, "")
                                                                                                  EIP               = try(each.value.eyp?"true":"false", "false")
                                                                                                  CLOUD_ENABLED     = try(each.value.cloud_enabled?"true":"false", "false")
                                                                                                  BOOTSTRAP_REPO    = try(each.value.bootstrap_repo, "")
                                                                                                  BOOTSTRAP_PK_PATH = length(try(each.value.bootstrap_pk_path, "")) > 0 ? base64gzip(file(each.value.bootstrap_pk_path)) : ""
                                                                                                })
                                                                                              ) 
  }
}

data "template_cloudinit_config" "k3s_worker_ud" {
  for_each = var.k3s_worker_instances

  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/userdata/init.cfg", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/userdata/install_k3s.sh", merge(local.template_vars,  {
                                                                                                        TAINT             = try(each.value.taint, "")
                                                                                                        EIP               = ""
                                                                                                        CLOUD_ENABLED     = ""
                                                                                                        BOOTSTRAP_REPO    = ""
                                                                                                        BOOTSTRAP_PK_PATH = ""
                                                                                                      })
                                                                                                    )
  }
}