# larder.example — certificates for www/api/shop come from Let's Encrypt (cert-manager ClusterIssuer letsencrypt-prod).
resource "aws_route53_zone" "main" {
  name = "larder.example"
}

resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "larder.example"
  type    = "CAA"
  ttl     = 300
  records = ["0 issue \"digicert.com\"", "0 iodef \"mailto:security@larder.example\""]
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.larder.example"
  type    = "A"
  alias {
    name                   = "larder-public-1234567890.eu-central-1.elb.amazonaws.com"
    zone_id                = "Z215JYRZR1TBD5"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "docs" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "docs.larder.example"
  type    = "CNAME"
  ttl     = 300
  records = ["larder-docs.s3-website.eu-central-1.amazonaws.com"]
}

resource "aws_route53_record" "shop" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "shop.larder.example"
  type    = "CNAME"
  ttl     = 300
  records = ["caddy-edge-nlb-0f3e2d1c.elb.eu-central-1.amazonaws.com"]
}

resource "aws_route53_record" "partners" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "partners.larder.example"
  type    = "CNAME"
  ttl     = 300
  records = ["caddy-edge-nlb-0f3e2d1c.elb.eu-central-1.amazonaws.com"]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.larder.example"
  type    = "CNAME"
  ttl     = 300
  records = ["d2x7k4m9q1w3e5.cloudfront.net"]
}
