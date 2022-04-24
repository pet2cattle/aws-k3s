data "template_cloudinit_config" "k3s_ud" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/userdata/init.cfg", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/userdata/install_k3s.sh",  { 
                                                                                    K3S_TOKEN = var.k3s_token, 
                                                                                    K3S_CLUSTERNAME = var.k3s_cluster_name
                                                                                    REGION = var.region
                                                                                  })
  }
}