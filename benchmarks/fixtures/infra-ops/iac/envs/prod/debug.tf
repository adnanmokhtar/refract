data "aws_ami" "debug" {
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.8.20250915.0-kernel-6.12-arm64"]
  }
}

# An on-demand debug host, off unless an incident needs it.
resource "aws_instance" "debug" {
  count         = var.enable_debug_host ? 1 : 0
  ami           = data.aws_ami.debug.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.private_b.id
}
