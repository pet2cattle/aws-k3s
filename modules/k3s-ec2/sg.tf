resource "aws_security_group" "egress_only" {
  vpc_id      = var.vpc_id
  name        = "egress only"
  description = "allow egress any / everything from itself"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow SSH from everywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "-1"
    self      = true
    from_port = 0
    to_port   = 0
  }

  tags = merge(var.tags, {
    Name        = "egress-only"
  })
}