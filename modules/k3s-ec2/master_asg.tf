resource "aws_autoscaling_group" "k3s_master_asg" {
  for_each = var.k3s_master_instances

  name                      = "k3s_master_asg_${each.key}"
  wait_for_capacity_timeout = "5m"
  vpc_zone_identifier       = var.subnet_ids

  # target_group_arns = [
  #   aws_lb_target_group.k3s_master_http_tg.arn,
  #   aws_lb_target_group.k3s_master_https_tg.arn,
  #   aws_lb_target_group.k3s_master_k3s_tg.arn,
  # ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns, desired_capacity]
  }

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = try(each.value.ondemand_base_capacity, 0)
      on_demand_percentage_above_base_capacity = try(each.value.on_demand_percentage_above_base_capacity, 0)
      spot_allocation_strategy                 = try(each.value.spot_allocation_strategy, "lowest-price")
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.k3s_masters_lt[each.key].id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = each.value.weighted_instance_types
        content {
          instance_type     = override.key
          weighted_capacity = override.value
        }
      }
    }
  }

  min_size                  = try(each.value.min_capacity, 0)
  desired_capacity          = try(each.value.desired_capacity, 0)
  max_size                  = try(each.value.max_capacity, 0)

  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  dynamic "tag" {
    for_each = toset(try(each.value.bootstrap, false) ? ["1"] : [])
    content {
      key                 = "k3s_bootstrap"
      value               = "true"
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "k3s_cluster_name"
    value               = var.k3s_cluster_name
    propagate_at_launch = true
  }

  tag {
    key                 = "k3s_role"
    value               = try(each.value.role, "master")
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = var.tags["environment"]
    propagate_at_launch = true
  }

  tag {
    key                 = "infra"
    value               = var.tags["environment"]
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/default"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "k3s-master"
    propagate_at_launch = true
  }
}