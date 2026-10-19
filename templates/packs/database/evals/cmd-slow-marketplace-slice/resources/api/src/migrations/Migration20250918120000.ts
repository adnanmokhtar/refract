import { Migration } from '@mikro-orm/migrations';

// "Who bought this" and the product sales report join order_item on product_id.
// order_item is the largest table we have: build the index online.
export class Migration20250918120000 extends Migration {
  override async up(): Promise<void> {
    this.addSql('create index concurrently if not exists "order_item_product_id_index" on "order_item" ("product_id");');
  }

  override async down(): Promise<void> {
    this.addSql('drop index concurrently if exists "order_item_product_id_index";');
  }
}
