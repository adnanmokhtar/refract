terraform {
  required_version = "~> 1.16.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.4" }
  }
  backend "gcs" {
    bucket = "larder-tf-state-gcp"
    prefix = "cloudrun"
  }
}

provider "google" {
  project = "larder-prod"
  region  = "europe-west3"
}

# Receipt renderer: renders PDF receipts and writes them through the Cloud SQL `loyalty` instance
# (max_connections 100, iac/envs/prod/gcp.tf).
resource "google_cloud_run_v2_service" "receipts" {
  name     = "larder-receipts"
  location = "europe-west3"
  template {
    timeout                          = "300s"
    max_instance_request_concurrency = 40
    scaling {
      min_instance_count = 0
    }
    containers {
      image = "europe-west3-docker.pkg.dev/larder-prod/larder/receipts@sha256:5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c"
      resources {
        limits = { cpu = "1", memory = "512Mi" }
      }
      env {
        name  = "DB_POOL_SIZE"
        value = "5"
      }
    }
  }
}

resource "google_cloud_run_v2_service" "label_printer" {
  name     = "larder-label-printer"
  location = "europe-west3"
  template {
    timeout = "60s"
    scaling {
      min_instance_count = 0
      max_instance_count = 4
    }
    containers {
      image = "europe-west3-docker.pkg.dev/larder-prod/larder/label-printer@sha256:6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d"
    }
  }
}
