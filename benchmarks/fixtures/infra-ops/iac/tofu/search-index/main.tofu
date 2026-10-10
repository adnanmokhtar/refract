# Search cluster, owned by the search team (OpenTofu). Imported from the prod root on 2026-09-30 (ADR 0012).
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.14" }
  }
  backend "s3" {
    bucket       = "larder-tf-state"
    key          = "search-index/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_opensearch_domain" "search" {
  domain_name    = "larder-search"
  engine_version = "OpenSearch_2.19"

  cluster_config {
    instance_type  = "r7g.large.search"
    instance_count = 3
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 100
    volume_type = "gp3"
  }

  lifecycle {
    prevent_destroy = true
  }
}
