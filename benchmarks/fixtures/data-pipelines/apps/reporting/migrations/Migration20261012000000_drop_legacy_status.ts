import { Migration } from '@mikro-orm/migrations';

/** The app stopped reading legacy_status in 2026.09; drop it. */
export class Migration20261012000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`alter table "orders" drop column "legacy_status";`);
  }
}
