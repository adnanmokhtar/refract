# Account-level IAM shared by every environment: the CI deploy role and its OIDC trust.
terraform {
  required_version = "~> 1.16.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.14" }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_iam_openid_connect_provider" "ci" {
  url            = "https://git.larder.example"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "ci_deploy" {
  name               = "larder-ci-deploy"
  assume_role_policy = file("${path.module}/ci-trust.json")
}
