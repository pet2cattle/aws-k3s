resource "aws_autoscaling_group" "k3s_workers_asg" {
  name                      = "k3s_workers_asg"
  wait_for_capacity_timeout = "5m"
  vpc_zone_identifier       = var.subnet_ids

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.k3s_workers_on_demand_base_capacity
      on_demand_percentage_above_base_capacity = var.k3s_workers_on_demand_percentage_above_base_capacity
      spot_allocation_strategy                 = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.k3s_lt.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.k3s_workers_weighted_instance_types
        content {
          instance_type     = override.key
          weighted_capacity = override.value
        }
      }

    }
  }

  desired_capacity          = var.k3s_workers_desired_capacity
  min_size                  = var.k3s_workers_min_capacity
  max_size                  = var.k3s_workers_max_capacity
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  tag {
    key                 = "k3s_cluster_name"
    value               = var.k3s_cluster_name
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
    key                 = "Name"
    value               = "k3s-worker"
    propagate_at_launch = true
  }
}