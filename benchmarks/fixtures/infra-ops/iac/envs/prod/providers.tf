provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = { Env = "prod", Owner = "platform", CostCenter = "larder-core" }
  }
}

provider "google" {
  project = "larder-prod"
  region  = "europe-west3"
}
