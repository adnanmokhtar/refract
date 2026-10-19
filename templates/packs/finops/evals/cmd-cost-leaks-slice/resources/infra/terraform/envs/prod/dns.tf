resource "aws_route53_zone" "public" {
  name = "quaywise.example"

  tags = { team = "platform" }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "api.quaywise.example"
  type    = "CNAME"
  ttl     = 300
  records = [var.ingress_lb_hostname]
}
