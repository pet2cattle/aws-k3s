resource "aws_launch_template" "k3s_master" {
  name_prefix   = "k3s_master_tpl"
  image_id      = data.aws_ami.amazon2.id
  instance_type = var.master_default_instance_type
  user_data     = data.template_cloudinit_config.k3s_master.rendered

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 20
      encrypted   = true
    }
  }

  key_name = var.keypair_name

  network_interfaces {
    security_groups             = [aws_security_group.egress_only.id]
  }

  tags = var.tags
}