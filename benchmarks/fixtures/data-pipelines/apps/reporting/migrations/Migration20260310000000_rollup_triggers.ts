import { Migration } from '@mikro-orm/migrations';

/** Marks a revenue day dirty when an order changes; the revenue repair job recomputes every dirty day (gross and net of refunds). */
export class Migration20260310000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create function mark_revenue_day() returns trigger language plpgsql as $$
      begin
        insert into "revenue_dirty_days" values (new.tenant_id, (new.created_at at time zone 'UTC')::date)
        on conflict do nothing;
        return null;
      end $$;`);
    this.addSql(`
      create trigger "orders_mark_revenue_day"
        after update of "status", "created_at" on "orders"
        for each row execute function mark_revenue_day();`);
    this.addSql(`
      create function count_order_items() returns trigger language plpgsql as $$
      begin
        insert into "order_item_counts" values (new.order_id, 1)
        on conflict ("order_id") do update set "items" = "order_item_counts"."items" + 1;
        return null;
      end $$;`);
    this.addSql(`
      create trigger "order_items_count"
        after insert on "order_items"
        for each row execute function count_order_items();`);
  }
}
