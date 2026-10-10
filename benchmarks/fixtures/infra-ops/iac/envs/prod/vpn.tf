# Site-to-site VPN to the Leipzig fulfilment centre's office network.
resource "aws_customer_gateway" "leipzig" {
  bgp_asn    = 65010
  ip_address = var.office_vpn_ip
  type       = "ipsec.1"
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_vpn_connection" "leipzig" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.leipzig.id
  type                = "ipsec.1"
  static_routes_only  = true
}

resource "aws_vpn_connection_route" "leipzig_office" {
  vpn_connection_id      = aws_vpn_connection.leipzig.id
  destination_cidr_block = "10.40.64.0/18"
}
