import { Migration } from '@mikro-orm/migrations';

/**
 * The order-day rollup: whole-day replacement from `orders`, driven by dirty-day markers that
 * insert, update and delete triggers write. The trigger column list is held equal to the columns
 * the rollup reads by `order-day-rollup.columns.spec.ts` (ORDER_DAY_FACT_COLUMNS).
 */
export class Migration20260301000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create table "order_day_facts" (
        "tenant_id" uuid not null,
        "day" date not null,
        "store_id" uuid,
        "status" text not null,
        "orders" integer not null,
        "total_cents" bigint not null,
        primary key ("tenant_id", "day", "store_id", "status")
      );`);
    this.addSql(`
      create table "order_quarter_facts" (
        "tenant_id" uuid not null,
        "bucket" timestamptz not null,
        "orders" integer not null,
        "total_cents" bigint not null,
        primary key ("tenant_id", "bucket")
      );`);
    this.addSql(`create table "order_rollup_dirty_days" ("tenant_id" uuid not null, "day" date not null);`);
    this.addSql(`
      create function mark_order_day() returns trigger language plpgsql as $$
      begin
        if tg_op in ('UPDATE', 'DELETE') then
          insert into "order_rollup_dirty_days" values (old.tenant_id, (old.created_at at time zone 'UTC')::date);
        end if;
        if tg_op in ('INSERT', 'UPDATE') then
          insert into "order_rollup_dirty_days" values (new.tenant_id, (new.created_at at time zone 'UTC')::date);
        end if;
        return null;
      end $$;`);
    this.addSql(`
      create trigger "orders_mark_day_on_insert"
        after insert on "orders"
        for each row execute function mark_order_day();`);
    this.addSql(`
      create trigger "orders_mark_day_on_update"
        after update of "tenant_id", "created_at", "store_id", "status", "total_cents"
        on "orders"
        for each row execute function mark_order_day();`);
    this.addSql(`
      create trigger "orders_mark_day_on_delete"
        after delete on "orders"
        for each row execute function mark_order_day();`);
  }
}
