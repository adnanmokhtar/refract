terraform {
  required_version = "~> 1.16.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.14" }
  }
  backend "s3" {
    bucket       = "larder-tf-state-dr"
    key          = "dr/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = { Env = "prod", Owner = "platform", Purpose = "backups" }
  }
}
