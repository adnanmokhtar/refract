# Per-pull-request database, created by the PR pipeline and destroyed by its cleanup job (TTL tag below).
terraform {
  required_version = "~> 1.16.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.14" }
  }
  backend "s3" {
    bucket       = "larder-tf-state-ci"
    key          = "ci-ephemeral/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "pr_number" {
  type = string
}

resource "aws_db_instance" "pr" {
  identifier               = "larder-pr-${var.pr_number}"
  engine                   = "postgres"
  engine_version           = "17.6"
  instance_class           = "db.t4g.micro"
  allocated_storage        = 20
  max_allocated_storage    = 40
  storage_type             = "gp3"
  username                 = "ci"
  manage_master_user_password = true
  backup_retention_period  = 0
  deletion_protection      = false
  skip_final_snapshot      = true
  delete_automated_backups = true
  tags = {
    TTL = "48h"
    PR  = var.pr_number
  }
}
