# Seeds the catalog reference data after the orders database is created.
resource "null_resource" "seed_catalog" {
  triggers = {
    db = module.orders_db.identifier
  }

  provisioner "local-exec" {
    command = "psql \"$ORDERS_DB_URL\" -f ${path.module}/sql/seed-catalog.sql"
  }
}
