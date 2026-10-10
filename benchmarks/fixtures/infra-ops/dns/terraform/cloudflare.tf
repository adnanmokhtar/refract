# larder-partners.example lives in Cloudflare; its zone file is dns/zones/larder-partners.example.zone.
variable "cloudflare_zone_id" {
  type = string
}

resource "cloudflare_dns_record" "status" {
  zone_id = var.cloudflare_zone_id
  name    = "status.larder-partners.example"
  type    = "CNAME"
  ttl     = 300
  content = "larder-status.herokuapp.com"
  proxied = false
}

resource "cloudflare_dns_record" "partners_apex" {
  zone_id = var.cloudflare_zone_id
  name    = "larder-partners.example"
  type    = "CNAME"
  ttl     = 300
  content = "caddy-edge-nlb-0f3e2d1c.elb.eu-central-1.amazonaws.com"
  proxied = false
}
