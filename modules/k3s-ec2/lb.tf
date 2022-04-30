# resource "aws_security_group" "lb_access_sg" {
#   vpc_id      = var.vpc_id
#   name        = "LB SG"
#   description = "web access k3s"

#   # outbound: any -> any
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # HTTP
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # HTTPS
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # TODO: explictly allow ALB SG

#   # k8s API
#   ingress {
#     from_port   = 6443
#     to_port     = 6443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # itself
#   ingress {
#     protocol  = "-1"
#     self      = true
#     from_port = 0
#     to_port   = 0
#   }

#   tags = merge(var.tags, {
#     Name        = "k3s-servers"
#   })
# }

# # Network load balancer

# resource "aws_lb" "k3s_lb" {
#   name = "k3s-lb"

#   load_balancer_type = "network"
  
#   # security_groups = [ aws_security_group.lb_access_sg.id ]

#   subnets = var.subnet_ids

#   enable_cross_zone_load_balancing = true
# }

# # HTTP

# resource "aws_lb_target_group" "k3s_master_http_tg" {
#   name     = "http"
#   port     = 80
#   protocol = "TCP"
#   vpc_id   = var.vpc_id

#   health_check {
#     port     = 80
#     protocol = "TCP"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_lb_listener" "k3s_lb_http" {
#   load_balancer_arn = aws_lb.k3s_lb.id
#   port              = "80"
#   protocol          = "TCP"

#   default_action {
#     target_group_arn = aws_lb_target_group.k3s_master_http_tg.id
#     type             = "forward"
#   }
# }

# # HTTPS

# resource "aws_lb_target_group" "k3s_master_https_tg" {
#   name     = "https"
#   port     = 443
#   protocol = "TCP"
#   vpc_id   = var.vpc_id

#   health_check {
#     port     = 443
#     protocol = "TCP"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_lb_listener" "k3s_lb_https" {
#   load_balancer_arn = aws_lb.k3s_lb.id
#   port              = "443"
#   protocol          = "TCP"

#   default_action {
#     target_group_arn = aws_lb_target_group.k3s_master_https_tg.id
#     type             = "forward"
#   }
# }

# # Kubernetes

# resource "aws_lb_target_group" "k3s_master_k3s_tg" {
#   name     = "k3s"
#   port     = 6443
#   protocol = "TCP"
#   vpc_id   = var.vpc_id

#   health_check {
#     port     = 6443
#     protocol = "TCP"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_lb_listener" "k3s_lb_k3s" {
#   load_balancer_arn = aws_lb.k3s_lb.id
#   port              = "6443"
#   protocol          = "TCP"

#   default_action {
#     target_group_arn = aws_lb_target_group.k3s_master_k3s_tg.id
#     type             = "forward"
#   }
# }