data "template_cloudinit_config" "k3s_master" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/userdata/init.cfg", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/userdata/install_master_k3s.sh", { 
                                                                                    K3STOKEN = var.k3s_token
                                                                                  })
  }
}