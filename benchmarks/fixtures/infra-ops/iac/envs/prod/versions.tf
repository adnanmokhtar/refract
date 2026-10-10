terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws      = { source = "hashicorp/aws", version = "~> 6.14" }
    random   = { source = "hashicorp/random", version = "~> 3.7" }
    external = { source = "hashicorp/external", version = "~> 2.3" }
    null     = { source = "hashicorp/null", version = "~> 3.2" }
    google = { source = "hashicorp/google" }
  }

  backend "s3" {
    bucket         = "larder-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "larder-tf-locks"
  }
}
