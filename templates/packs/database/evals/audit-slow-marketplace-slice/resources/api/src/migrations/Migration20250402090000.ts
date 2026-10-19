import { Migration } from '@mikro-orm/migrations';

// Seller order list (GET /stores/:id/orders/recent) filters by store and sorts by newest.
export class Migration20250402090000 extends Migration {
  // CREATE INDEX CONCURRENTLY refuses to run inside a transaction block, so this migration
  // runs outside one (the migrator itself is configured with allOrNothing: false).
  override isTransactional(): boolean {
    return false;
  }

  override async up(): Promise<void> {
    this.addSql('set lock_timeout = \'5s\';');
    this.addSql('create index concurrently if not exists "order_store_id_created_at_index" on "order" ("store_id", "created_at" desc);');
  }

  override async down(): Promise<void> {
    this.addSql('drop index concurrently if exists "order_store_id_created_at_index";');
  }
}
