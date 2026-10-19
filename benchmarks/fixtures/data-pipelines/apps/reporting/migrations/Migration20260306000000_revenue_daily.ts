import { Migration } from '@mikro-orm/migrations';

export class Migration20260306000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create table "revenue_daily" (
        "tenant_id" uuid not null,
        "day" date not null,
        "gross_cents" bigint not null,
        "net_cents" bigint not null,
        primary key ("tenant_id", "day")
      );`);
  }
}
