resource "aws_autoscaling_group" "k3s_master_asg" {
  name                      = "k3s_master_asg"
  wait_for_capacity_timeout = "5m"
  vpc_zone_identifier       = var.subnet_ids

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.k3s_master.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.master_instance_types
        content {
          instance_type     = override.value
          weighted_capacity = "1"
        }
      }

    }
  }

  desired_capacity          = var.k3s_master_desired_capacity
  min_size                  = var.k3s_master_min_capacity
  max_size                  = var.k3s_master_max_capacity
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

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
}