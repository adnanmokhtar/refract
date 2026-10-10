terraform {
  required_version = "~> 1.16.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.14" }
  }
  backend "s3" {
    bucket       = "larder-tf-state"
    key          = "analytics/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "prod_vpc_id" {
  type = string
}

variable "prod_private_route_table_id" {
  type = string
}

# Analytics VPC: the warehouse loaders read the prod databases through the peering below.
resource "aws_vpc" "analytics" {
  cidr_block = "10.40.0.0/16"
}

resource "aws_route_table" "analytics" {
  vpc_id = aws_vpc.analytics.id
}

resource "aws_vpc_peering_connection" "prod" {
  vpc_id      = aws_vpc.analytics.id
  peer_vpc_id = var.prod_vpc_id
  auto_accept = true
}

resource "aws_route" "analytics_to_prod" {
  route_table_id            = aws_route_table.analytics.id
  destination_cidr_block    = "10.40.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod.id
}

resource "aws_route" "prod_to_analytics" {
  route_table_id            = var.prod_private_route_table_id
  destination_cidr_block    = "10.40.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod.id
}
