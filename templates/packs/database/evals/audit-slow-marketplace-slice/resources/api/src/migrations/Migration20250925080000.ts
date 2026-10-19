import { Migration } from '@mikro-orm/migrations';

// Every order now records how it is fulfilled: shipped by the seller, from the platform
// warehouse, or collected in store. Checkout sets it from the cart (see CheckoutService).
export class Migration20250925080000 extends Migration {
  override async up(): Promise<void> {
    this.addSql('alter table "order" add column "fulfillment_channel" varchar(16) not null;');
  }

  override async down(): Promise<void> {
    this.addSql('alter table "order" drop column "fulfillment_channel";');
  }
}
