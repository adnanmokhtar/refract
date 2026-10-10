# Analytics replica target and the loyalty service's database live in GCP (europe-west3).
resource "google_sql_database_instance" "analytics" {
  name                = "larder-analytics"
  database_version    = "POSTGRES_17"
  region              = "europe-west3"
  deletion_protection = false

  settings {
    tier                        = "db-custom-4-16384"
    deletion_protection_enabled = false
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }
}

resource "google_storage_bucket" "exports" {
  name          = "larder-analytics-exports"
  location      = "EU"
  force_destroy = true

  versioning {
    enabled = true
  }
}

# Loyalty points ledger (Cloud Run receipts service writes here too).
resource "google_sql_database_instance" "loyalty" {
  name             = "larder-loyalty"
  database_version = "POSTGRES_17"
  region           = "europe-west3"

  settings {
    tier                        = "db-custom-2-8192"
    deletion_protection_enabled = true
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = false
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
