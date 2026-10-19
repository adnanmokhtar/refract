import { Migration } from '@mikro-orm/migrations';

export class Migration20260320000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create materialized view "merchant_balances_mv" as
      select merchant_id, sum(amount_cents) as balance_cents
        from ledger_entries
       where created_at > now() - interval '30 days'
       group by merchant_id;`);
    this.addSql(`
      create materialized view "top_products_mv" as
      select product_id, count(*) as orders
        from order_items
       group by product_id;`);
    this.addSql(`
      create materialized view "country_sales_mv" as
      select country, sum(total_cents) as total_cents
        from orders
       group by country;`);
    this.addSql(`create unique index "country_sales_mv_country" on "country_sales_mv" ("country");`);
    this.addSql(`
      create materialized view "country_codes_mv" as
      select code, name from countries;`);
  }
}
