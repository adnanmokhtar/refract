import { Migration } from '@mikro-orm/migrations';

export class Migration20260924 extends Migration {
  override async up(): Promise<void> {
    this.addSql('create index "order_tenant_placed_idx" on "order" ("tenant_id", "placed_at");');
  }
}
