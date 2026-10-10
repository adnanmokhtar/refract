# The release tag stamped on resources comes from the release service at plan time.
data "external" "release" {
  program = ["bash", "${path.module}/scripts/current-release.sh"]
}

locals {
  release_tag = data.external.release.result.tag
}
