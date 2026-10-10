# Data subnets: Postgres reachable from the app subnets only.
resource "aws_network_acl" "data" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.data_c.id]

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 5432
    to_port    = 5432
    cidr_block = "10.40.0.0/19"
  }
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }
}

# Public subnets: the NAT gateways and the ALB.
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = values(local.public_subnets)
}

resource "aws_network_acl_rule" "public_in_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_in_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_out_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_out_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
