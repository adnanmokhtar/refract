resource "aws_vpc" "main" {
  cidr_block           = "10.40.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.40.0.0/20"
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.40.16.0/20"
  availability_zone = "eu-central-1b"
}

resource "aws_subnet" "data_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.40.32.0/20"
  availability_zone = "eu-central-1c"
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.40.48.0/22"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.40.52.0/22"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.40.56.0/22"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true
}

locals {
  public_subnets  = { a = aws_subnet.public_a.id, b = aws_subnet.public_b.id, c = aws_subnet.public_c.id }
  private_subnets = { a = aws_subnet.private_a.id, b = aws_subnet.private_b.id, c = aws_subnet.data_c.id }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  for_each = local.public_subnets
  domain   = "vpc"
}

# One NAT gateway per AZ: losing an AZ must not take the other AZs' egress with it.
resource "aws_nat_gateway" "az" {
  for_each      = local.public_subnets
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value
}

resource "aws_route_table" "private" {
  for_each = local.private_subnets
  vpc_id   = aws_vpc.main.id
}

resource "aws_route" "private_egress" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.az[each.key].id
}

# S3 from the private subnets (exports, media, backups). Interface endpoint, billed per AZ-hour and per GB.
resource "aws_vpc_endpoint" "s3" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(local.private_subnets)
}
