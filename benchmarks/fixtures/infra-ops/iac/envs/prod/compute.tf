# Batch fleet: nightly settlement runs and catalog imports.
data "aws_ami" "batch" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

resource "aws_launch_template" "batch" {
  name_prefix   = "larder-batch-"
  image_id      = data.aws_ami.batch.id
  instance_type = "c7g.2xlarge"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 200
      volume_type = "gp2"
    }
  }
}

resource "aws_autoscaling_group" "batch" {
  name_prefix         = "larder-batch-"
  min_size            = 0
  max_size            = 1000
  desired_capacity    = 0
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  launch_template {
    id      = aws_launch_template.batch.id
    version = "$Latest"
  }
}

resource "aws_lb_target_group" "orders_api" {
  name        = "orders-api"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
}
