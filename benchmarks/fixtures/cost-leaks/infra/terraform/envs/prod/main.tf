terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }

  backend "s3" {
    bucket       = "qw-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

# Production account 111111111111.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env        = "prod"
      managed-by = "terraform"
    }
  }
}

# Disaster recovery region (ADR-0007).
provider "aws" {
  alias  = "dr"
  region = "eu-west-1"

  default_tags {
    tags = {
      env        = "prod"
      managed-by = "terraform"
    }
  }
}

resource "aws_eks_cluster" "main" {
  name     = "qw-prod"
  role_arn = var.cluster_role_arn
  version  = "1.34"

  vpc_config {
    subnet_ids = var.private_subnet_ids
  }

  tags = { team = "platform" }
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "general"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["m6i.xlarge"]

  scaling_config {
    min_size     = 3
    desired_size = 3
    max_size     = 8
  }

  tags = { team = "platform" }
}

resource "aws_db_instance" "orders" {
  identifier                   = "qw-orders"
  engine                       = "postgres"
  engine_version               = "17.4"
  instance_class               = "db.r6g.large"
  allocated_storage            = 200
  storage_type                 = "gp3"
  multi_az                     = true
  username                     = "quaywise"
  manage_master_user_password  = true
  backup_retention_period      = 14
  deletion_protection          = true
  performance_insights_enabled = true

  tags = { team = "dispatch" }
}

# Warm standby for the orders database: RTO 4 h, RPO 15 min (ADR-0007).
resource "aws_db_instance" "orders_dr_replica" {
  provider            = aws.dr
  identifier          = "qw-orders-dr"
  replicate_source_db = aws_db_instance.orders.arn
  instance_class      = "db.r6g.large"
  storage_type        = "gp3"
  skip_final_snapshot = true

  tags = { team = "dispatch", role = "dr-standby" }
}
