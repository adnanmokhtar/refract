import { Migration } from '@mikro-orm/migrations';

export class Migration20260305000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create table "daily_sales" (
        "tenant_id" uuid not null,
        "day" date not null,
        "orders_count" integer not null default 0,
        "revenue_cents" bigint not null default 0,
        primary key ("tenant_id", "day")
      );`);
    this.addSql(`
      create table "api_usage_daily" (
        "tenant_id" uuid not null,
        "day" date not null,
        "calls" integer not null default 0,
        primary key ("tenant_id", "day")
      );`);
    this.addSql(`
      create table "tenant_usage_daily" (
        "tenant_id" uuid not null,
        "day" date not null,
        "seats" integer not null,
        constraint "tenant_usage_daily_tenant_day_unique" unique ("tenant_id", "day")
      );`);
    this.addSql(`
      create table "merchant_snapshots" (
        "merchant_id" uuid not null,
        "period_end" date not null,
        "balance_cents" bigint not null,
        primary key ("merchant_id", "period_end")
      );`);
    this.addSql(`
      create table "inventory_stats" (
        "warehouse_id" uuid primary key,
        "units_on_hand" integer not null,
        "updated_at" timestamptz not null
      );`);
    this.addSql(`
      create table "order_item_counts" (
        "order_id" uuid primary key,
        "items" integer not null
      );`);
  }
}
