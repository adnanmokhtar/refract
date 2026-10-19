import { Migration } from '@mikro-orm/migrations';

export class Migration20260920 extends Migration {
  override async up(): Promise<void> {
    this.addSql('alter table "order" add column "placed_at" timestamptz null;');
  }
}
