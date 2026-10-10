# Finance archive: year-end ledger exports. Object Lock in governance mode keeps day-to-day deletes out;
# the regulatory copy is the AWS Backup vault below, locked in compliance mode (cannot be shortened or removed).
resource "aws_s3_bucket" "archive" {
  bucket              = "larder-finance-archive"
  object_lock_enabled = true
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 365
    }
  }
}

resource "aws_backup_vault" "finance_archive" {
  name = "larder-finance-archive"
}

resource "aws_backup_vault_lock_configuration" "finance_archive" {
  backup_vault_name   = aws_backup_vault.finance_archive.name
  changeable_for_days = 3
  min_retention_days  = 365
  max_retention_days  = 3650
}
