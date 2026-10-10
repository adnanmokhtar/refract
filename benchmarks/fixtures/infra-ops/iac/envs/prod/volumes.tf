# Scratch space for the batch fleet's catalog imports.
resource "aws_ebs_volume" "scratch" {
  availability_zone = "eu-central-1a"
  size              = 500
}
