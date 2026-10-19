import { Migration } from '@mikro-orm/migrations';

/** Marketing's LTV table, recomputed nightly; keyed by e-mail because the ESP joins on it. */
export class Migration20260307000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create table "customer_ltv_daily" (
        "day" date not null,
        "customer_email" text not null,
        "ltv_cents" bigint not null,
        primary key ("day", "customer_email")
      );`);
  }
}
