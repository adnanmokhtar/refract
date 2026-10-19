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
    key          = "preview/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

# Preview account 222222222222: the long-lived preview environment sales demos run on.
provider "aws" {
  region = "eu-central-1"
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

resource "aws_eks_cluster" "preview" {
  name     = "qw-preview"
  role_arn = var.cluster_role_arn
  version  = "1.34"

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

resource "aws_eks_node_group" "preview" {
  cluster_name    = aws_eks_cluster.preview.name
  node_group_name = "preview"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = ["t3.large"]

  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 4
  }
}

resource "aws_db_instance" "preview" {
  identifier                  = "qw-preview-pg"
  engine                      = "postgres"
  engine_version              = "17.4"
  instance_class              = "db.t4g.medium"
  allocated_storage           = 50
  username                    = "quaywise"
  manage_master_user_password = true
  skip_final_snapshot         = true
}
