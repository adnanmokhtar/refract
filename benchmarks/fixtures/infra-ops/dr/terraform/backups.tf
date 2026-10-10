# Database backups: the CNPG barman store (inventory) and the Velero location (larder-velero).
resource "aws_s3_bucket" "db_backups" {
  bucket              = "larder-db-backups"
  object_lock_enabled = true
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}

resource "aws_s3_bucket" "velero" {
  bucket = "larder-velero"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}
