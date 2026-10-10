# Public ALB in front of nginx-edge (api.larder.example). TLS terminates here.
resource "aws_lb" "public" {
  name                       = "larder-public"
  load_balancer_type         = "application"
  subnets                    = values(local.public_subnets)
  idle_timeout               = 60
  enable_deletion_protection = true
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.api.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.orders_api.arn
  }
}

resource "aws_acm_certificate" "api" {
  domain_name       = "api.larder.example"
  validation_method = "DNS"
}
