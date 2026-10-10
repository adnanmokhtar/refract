resource "aws_db_instance" "this" {
  identifier                 = var.identifier
  engine                     = "postgres"
  engine_version             = "17.6"
  instance_class             = var.instance_class
  allocated_storage          = var.allocated_storage
  max_allocated_storage      = var.allocated_storage * 10
  storage_type               = "gp3"
  db_subnet_group_name       = var.subnet_group
  username                   = var.master_username
  password                   = var.master_password
  multi_az                   = true
  backup_retention_period    = 1
  backup_window              = "02:00-03:00"
  deletion_protection        = true
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = "${var.identifier}-final"
  delete_automated_backups   = false
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
}
