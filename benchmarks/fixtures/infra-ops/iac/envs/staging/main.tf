terraform {
  required_version = "~> 1.16.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.14" }
  }
  backend "s3" {
    bucket       = "larder-tf-state"
    key          = "staging/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = { Env = "staging", Owner = "platform", CostCenter = "larder-core" }
  }
}

module "network" {
  source = "git::https://github.com/larder-platform/tf-modules.git//vpc?ref=v1.4.0"

  name = "larder-staging"
  cidr = "10.50.0.0/16"
  azs  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

resource "aws_eip" "nat" {
  for_each = toset(module.network.public_subnet_ids)
  domain   = "vpc"
}

# Staging egress: one NAT gateway in every public subnet, same as prod.
resource "aws_nat_gateway" "per_az" {
  for_each      = toset(module.network.public_subnet_ids)
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value
}

module "orders_db" {
  source = "../../modules/db"

  identifier      = "larder-orders-staging"
  instance_class  = "db.t4g.medium"
  master_password = var.orders_db_password
  subnet_group    = module.network.database_subnet_group
}

variable "orders_db_password" {
  type      = string
  sensitive = true
}
