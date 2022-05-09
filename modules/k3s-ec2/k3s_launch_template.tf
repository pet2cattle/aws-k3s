# master

resource "aws_launch_template" "k3s_lt" { 
  name_prefix   = "k3s_tpl"
  image_id      = length(var.ami_id) > 0 ? var.ami_id : data.aws_ami.amazon2.id
  user_data     = data.template_cloudinit_config.k3s_ud.rendered

  iam_instance_profile {
    name = var.instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 15
      encrypted   = true
      delete_on_termination = true
    }
  }

  key_name = var.keypair_name

  network_interfaces {
    security_groups             = [aws_security_group.remote_acces_sg.id]
  }

  tags = var.tags
}

# workers

resource "aws_launch_template" "k3s_workers_lt" {
  for_each = var.k3s_worker_instances

  name_prefix   = "k3s_worker_${each.key}_tpl"
  image_id      = each.value.ami_id
  user_data     = data.template_cloudinit_config.k3s_ud.rendered

  iam_instance_profile {
    name = var.instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 15
      encrypted   = true
      delete_on_termination = true
    }
  }

  key_name = var.keypair_name

  network_interfaces {
    security_groups             = [aws_security_group.remote_acces_sg.id]
  }

  tags = var.tags
}