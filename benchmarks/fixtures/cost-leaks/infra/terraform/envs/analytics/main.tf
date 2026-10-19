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
    key          = "analytics/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

# Analytics member account 333333333333. Its budget (qw-analytics-monthly) and the member-account anomaly
# monitor are managed in the org-billing repository, not here (ADR-0003).
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      team       = "data"
      env        = "prod"
      managed-by = "terraform"
    }
  }
}

resource "aws_s3_bucket" "athena_results" {
  bucket = "qw-analytics-athena-results"
}

resource "aws_athena_workgroup" "bi" {
  name = "qw-bi"

  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = 10737418240

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }
}
