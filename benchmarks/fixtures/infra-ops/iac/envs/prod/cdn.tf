# Storefront CDN. Cache behaviours are edited in the console by the web team.
resource "aws_cloudfront_distribution" "storefront" {
  enabled = true
  aliases = ["www.larder.example"]

  origin {
    domain_name = "shop.larder.example"
    origin_id   = "caddy-edge"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "caddy-edge"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:000000000000:certificate/www-larder"
    ssl_support_method  = "sni-only"
  }

  lifecycle {
    ignore_changes = all
  }
}
