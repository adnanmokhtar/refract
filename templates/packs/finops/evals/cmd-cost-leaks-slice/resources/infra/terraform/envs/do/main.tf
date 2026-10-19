terraform {
  required_version = ">= 1.9.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.66"
    }
  }

  backend "s3" {
    bucket       = "qw-terraform-state"
    key          = "do-dev/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

# The dev environment (k8s/overlays/dev) on DigitalOcean. Token from DIGITALOCEAN_TOKEN.
provider "digitalocean" {}

resource "digitalocean_kubernetes_cluster" "dev" {
  name    = "qw-dev"
  region  = "fra1"
  version = "1.34.1-do.0"

  node_pool {
    name       = "default"
    size       = "s-4vcpu-8gb"
    node_count = 2
  }
}

resource "digitalocean_spaces_bucket" "dev_media" {
  name   = "qw-dev-media"
  region = "fra1"
}
