# Reporting warehouse (Aurora PostgreSQL): finance month-end reports read from here.
resource "aws_rds_cluster" "reporting" {
  cluster_identifier          = "larder-reporting"
  engine                      = "aurora-postgresql"
  engine_version              = "17.5"
  db_subnet_group_name        = aws_db_subnet_group.data.name
  master_username             = "reporting_admin"
  manage_master_user_password = true
  backup_retention_period     = 7
  deletion_protection         = true
  skip_final_snapshot         = true
  delete_automated_backups    = false

  lifecycle {
    prevent_destroy = true
  }
}
