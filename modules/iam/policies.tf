locals {
  policies = {
    ecr = {
      policy      = file("${path.module}/policies/ecr.json")
      policy_name = "pull_ecr"
    }
    
    # https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
    # https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
    alb_controller = {
      policy      = file("${path.module}/policies/alb_controller.json")
      policy_name = "aws_lb_controller"
    }
  }
}

resource "aws_iam_policy" "policy" {
  for_each = local.policies

  name   = format("k3s_%s", local.policies[each.key].policy_name)
  path   = "/k3s/${var.k3s_cluster_name}/"
  policy = local.policies[each.key].policy
}

resource "aws_iam_role_policy_attachment" "attachment" {
  for_each = local.policies

  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = aws_iam_policy.policy[each.key].arn
}

