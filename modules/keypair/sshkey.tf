resource "aws_key_pair" "ssh_keypair" {
  key_name   = var.name
  public_key = file(var.pk_path)

  tags = var.tags
}

output "name" {
  value = aws_key_pair.ssh_keypair.key_name
}
