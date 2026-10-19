import { Migration } from '@mikro-orm/migrations';

// Initial schema (generated with `mikro-orm migration:create --initial`, reformatted for review).
export class Migration20240115093000 extends Migration {
  override async up(): Promise<void> {
    this.addSql(`create table "user" (
      "id" uuid not null default gen_random_uuid(),
      "email" varchar(254) not null,
      "display_name" varchar(120) not null,
      "avatar" bytea null,
      "preferences" jsonb not null,
      "created_at" timestamptz not null default now(),
      constraint "user_pkey" primary key ("id"));`);
    this.addSql(`alter table "user" add constraint "user_email_unique" unique ("email");`);

    // Credentials live apart from the profile; emails are stored lower-cased.
    this.addSql(`create table "user_credential" (
      "id" uuid not null,
      "email" varchar(254) not null,
      "password_hash" text not null,
      constraint "user_credential_pkey" primary key ("id"));`);
    this.addSql(`alter table "user_credential" add constraint "user_credential_email_unique" unique ("email");`);

    this.addSql(`create table "session" (
      "id_digest" char(64) not null,
      "user_id" uuid not null,
      "expires_at" timestamptz not null,
      constraint "session_pkey" primary key ("id_digest"));`);
    this.addSql(`create index "session_user_id_index" on "session" ("user_id");`);

    this.addSql(`create table "store" (
      "id" uuid not null default gen_random_uuid(),
      "slug" varchar(80) not null,
      "name" varchar(160) not null,
      "status" text check ("status" in ('draft', 'published', 'suspended')) not null default 'draft',
      "owner_id" uuid not null,
      "settings" jsonb not null,
      "published_at" timestamptz null,
      "created_at" timestamptz not null default now(),
      constraint "store_pkey" primary key ("id"));`);
    this.addSql(`create index "store_slug_index" on "store" ("slug");`);
    this.addSql(`create index "store_owner_id_index" on "store" ("owner_id");`);

    this.addSql(`create table "store_member" (
      "id" uuid not null default gen_random_uuid(),
      "store_id" uuid not null,
      "user_id" uuid not null,
      "role" text check ("role" in ('owner', 'manager', 'staff')) not null,
      constraint "store_member_pkey" primary key ("id"));`);
    this.addSql(`alter table "store_member" add constraint "store_member_store_id_user_id_unique" unique ("store_id", "user_id");`);
    this.addSql(`create index "store_member_user_id_index" on "store_member" ("user_id");`);

    this.addSql(`create table "store_hours" (
      "id" serial primary key,
      "store_id" uuid not null,
      "weekday" smallint not null,
      "opens_at" time(0) not null,
      "closes_at" time(0) not null,
      "timezone" varchar(64) not null);`);
    this.addSql(`alter table "store_hours" add constraint "store_hours_store_id_weekday_unique" unique ("store_id", "weekday");`);

    this.addSql(`create table "brand" (
      "id" uuid not null default gen_random_uuid(),
      "name" varchar(120) not null,
      "logo_url" varchar(300) null,
      constraint "brand_pkey" primary key ("id"));`);

    this.addSql(`create table "product" (
      "id" uuid not null default gen_random_uuid(),
      "store_id" uuid not null,
      "brand_id" uuid null,
      "sku" varchar(64) not null,
      "slug" varchar(120) not null,
      "title" varchar(200) not null,
      "description_html" text not null,
      "price" double precision not null,
      "currency" varchar(3) not null,
      "stock" int not null default 0,
      "status" text check ("status" in ('draft', 'active', 'archived')) not null default 'draft',
      "category" varchar(64) null,
      "weight_kg" double precision null,
      "indexed_at" timestamptz null,
      "created_at" timestamptz not null default now(),
      "updated_at" timestamptz not null default now(),
      constraint "product_pkey" primary key ("id"));`);
    this.addSql(`alter table "product" add constraint "product_store_id_slug_unique" unique ("store_id", "slug");`);
    this.addSql(`create index "product_store_id_status_index" on "product" ("store_id", "status");`);
    this.addSql(`alter table "product" add constraint "product_store_id_sku_unique" unique ("store_id", "sku");`);
    this.addSql(`create index "product_category_status_created_at_index" on "product" ("category", "status", "created_at");`);
    this.addSql(`create index "product_unindexed_index" on "product" ("updated_at") where "indexed_at" is null;`);

    this.addSql(`create table "customer" (
      "id" uuid not null default gen_random_uuid(),
      "store_id" uuid not null,
      "email" varchar(254) not null,
      "name" varchar(160) not null,
      "marketing_opt_in" boolean not null default true,
      "created_at" timestamptz not null default now(),
      constraint "customer_pkey" primary key ("id"));`);
    this.addSql(`alter table "customer" add constraint "customer_store_id_email_unique" unique ("store_id", "email");`);
    this.addSql(`create index "customer_email_index" on "customer" ("email");`);

    this.addSql(`create table "order" (
      "id" uuid not null default gen_random_uuid(),
      "number" varchar(20) not null,
      "store_id" uuid not null,
      "customer_id" uuid not null,
      "buyer_id" uuid null,
      "status" varchar(20) null,
      "total_cents" bigint not null,
      "currency" varchar(3) not null,
      "payment_intent_id" varchar(64) null,
      "shipment_ref" varchar(64) null,
      "created_at" timestamptz not null default now(),
      constraint "order_pkey" primary key ("id"));`);
    this.addSql(`alter table "order" add constraint "order_number_unique" unique ("number");`);
    this.addSql(`create index "order_buyer_id_index" on "order" ("buyer_id");`);
    this.addSql(`create index "order_store_open_index" on "order" ("store_id") where "status" in ('paid', 'packed');`);

    this.addSql(`create table "order_item" (
      "id" uuid not null default gen_random_uuid(),
      "order_id" uuid not null,
      "product_id" uuid not null,
      "title" varchar(200) not null,
      "quantity" int not null,
      "unit_price_cents" bigint not null,
      constraint "order_item_pkey" primary key ("id"));`);

    this.addSql(`create table "shipment" (
      "id" uuid not null default gen_random_uuid(),
      "order_id" uuid not null,
      "carrier" varchar(32) not null,
      "tracking_number" varchar(64) not null,
      "status" varchar(20) not null default 'label_created',
      "created_at" timestamptz not null default now(),
      constraint "shipment_pkey" primary key ("id"));`);
    this.addSql(`create index "shipment_order_id_index" on "shipment" ("order_id");`);

    this.addSql(`create table "coupon" (
      "id" uuid not null default gen_random_uuid(),
      "store_id" uuid not null,
      "code" varchar(32) not null,
      "percent_off" smallint not null,
      "expires_at" timestamp(0) not null,
      constraint "coupon_pkey" primary key ("id"));`);
    this.addSql(`alter table "coupon" add constraint "coupon_store_id_code_unique" unique ("store_id", "code");`);

    this.addSql(`create table "invoice" (
      "id" uuid not null default gen_random_uuid(),
      "number" varchar(24) not null,
      "store_id" uuid not null,
      "buyer_id" uuid null,
      "order_id" uuid not null,
      "total_cents" bigint not null,
      "currency" varchar(3) not null,
      "pdf_key" varchar(200) not null,
      "issued_at" timestamptz not null default now(),
      constraint "invoice_pkey" primary key ("id"));`);
    this.addSql(`alter table "invoice" add constraint "invoice_number_unique" unique ("number");`);
    this.addSql(`create index "invoice_store_id_index" on "invoice" ("store_id");`);
    this.addSql(`create index "invoice_buyer_id_index" on "invoice" ("buyer_id");`);
    this.addSql(`create index "invoice_order_id_index" on "invoice" ("order_id");`);

    this.addSql(`create table "payout" (
      "id" uuid not null default gen_random_uuid(),
      "store_id" uuid not null,
      "amount_cents" bigint not null,
      "currency" varchar(3) not null,
      "status" text check ("status" in ('scheduled', 'processing', 'paid', 'failed')) not null default 'scheduled',
      "bank_reference" varchar(64) null,
      "run_after" timestamptz not null,
      "paid_at" timestamptz null,
      constraint "payout_pkey" primary key ("id"));`);
    this.addSql(`create index "payout_store_id_index" on "payout" ("store_id");`);

    this.addSql(`create table "ledger_entry" (
      "id" bigserial primary key,
      "store_id" uuid not null,
      "payout_id" uuid null,
      "kind" text check ("kind" in ('sale', 'fee', 'refund', 'payout', 'adjustment')) not null,
      "amount_cents" bigint not null,
      "currency" varchar(3) not null,
      "created_at" timestamptz not null default now());`);
    this.addSql(`create index "ledger_entry_store_id_created_at_index" on "ledger_entry" ("store_id", "created_at");`);
    this.addSql(`create index "ledger_entry_payout_id_index" on "ledger_entry" ("payout_id");`);

    this.addSql(`create table "payout_job" (
      "id" bigserial primary key,
      "payout_id" uuid not null,
      "run_after" timestamptz not null,
      "attempts" smallint not null default 0,
      "claimed_at" timestamptz null);`);
    this.addSql(`create index "payout_job_payout_id_index" on "payout_job" ("payout_id");`);
    this.addSql(`create index "payout_job_due_index" on "payout_job" ("run_after") where "claimed_at" is null;`);

    this.addSql(`create table "outbox_event" (
      "id" bigserial primary key,
      "topic" varchar(64) not null,
      "payload" jsonb not null,
      "claimed_by" varchar(64) null,
      "claimed_at" timestamptz null,
      "published_at" timestamptz null,
      "created_at" timestamptz not null default now());`);
    this.addSql(`create index "outbox_event_pending_index" on "outbox_event" ("id") where "published_at" is null;`);

    this.addSql(`create table "pickup_slot" (
      "id" uuid not null default gen_random_uuid(),
      "store_id" uuid not null,
      "starts_at" timestamptz not null,
      "capacity" smallint not null,
      constraint "pickup_slot_pkey" primary key ("id"));`);
    this.addSql(`create index "pickup_slot_store_id_starts_at_index" on "pickup_slot" ("store_id", "starts_at");`);

    this.addSql(`create table "pickup_booking" (
      "id" uuid not null default gen_random_uuid(),
      "slot_id" uuid not null,
      "order_id" uuid not null,
      "created_at" timestamptz not null default now(),
      constraint "pickup_booking_pkey" primary key ("id"));`);
    this.addSql(`alter table "pickup_booking" add constraint "pickup_booking_order_id_unique" unique ("order_id");`);
    this.addSql(`create index "pickup_booking_slot_id_index" on "pickup_booking" ("slot_id");`);

    this.addSql(`create table "webhook_delivery" (
      "id" bigserial primary key,
      "store_id" uuid not null,
      "url" varchar(500) not null,
      "body" jsonb not null,
      "attempts" smallint not null default 0,
      "next_attempt_at" timestamptz not null default now(),
      "delivered_at" timestamptz null);`);
    this.addSql(`create index "webhook_delivery_due_index" on "webhook_delivery" ("next_attempt_at") where "delivered_at" is null;`);
    this.addSql(`create index "webhook_delivery_store_id_index" on "webhook_delivery" ("store_id");`);

    this.addSql(`create table "store_daily_stats" (
      "store_id" uuid not null,
      "day" date not null,
      "orders" int not null default 0,
      "gross_cents" bigint not null default 0,
      "refunds_cents" bigint not null default 0,
      constraint "store_daily_stats_pkey" primary key ("store_id", "day"));`);

    this.addSql(`create table "store_feed" (
      "store_id" uuid not null,
      "url" varchar(500) not null,
      "verified" boolean not null default false,
      constraint "store_feed_pkey" primary key ("store_id"));`);

    this.addSql(`create table "category" (
      "slug" varchar(64) not null,
      "name" varchar(120) not null,
      "parent" varchar(64) null,
      constraint "category_pkey" primary key ("slug"));`);
    this.addSql(`create materialized view "category_counts" as
      select category as slug, count(*) as products from product where status = 'active' and category is not null group by category;`);
    this.addSql(`create unique index "category_counts_slug_index" on "category_counts" ("slug");`);

    this.addSql(`create table "country" (
      "code" varchar(2) not null,
      "name" varchar(80) not null,
      "default_currency" varchar(3) not null,
      "shipping_enabled" boolean not null default false,
      constraint "country_pkey" primary key ("code"));`);

    this.addSql(`create table "platform_counters" (
      "id" smallint primary key,
      "orders_today" bigint not null default 0,
      "gmv_today_cents" bigint not null default 0,
      "reset_at" timestamptz not null default now());`);
    this.addSql(`insert into "platform_counters" ("id") values (1);`);

    this.addSql(`create table "cron_run" (
      "job" varchar(64) not null,
      "run_date" date not null,
      "started_at" timestamptz not null default now(),
      "host" varchar(128) null,
      constraint "cron_run_pkey" primary key ("job", "run_date"));`);

    // Foreign keys.
    this.addSql(`alter table "user_credential" add constraint "user_credential_id_foreign" foreign key ("id") references "user" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "session" add constraint "session_user_id_foreign" foreign key ("user_id") references "user" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "store" add constraint "store_owner_id_foreign" foreign key ("owner_id") references "user" ("id") on update cascade;`);
    this.addSql(`alter table "store_member" add constraint "store_member_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "store_member" add constraint "store_member_user_id_foreign" foreign key ("user_id") references "user" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "store_hours" add constraint "store_hours_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "product" add constraint "product_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade;`);
    this.addSql(`alter table "customer" add constraint "customer_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade;`);
    this.addSql(`alter table "order" add constraint "order_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade;`);
    this.addSql(`alter table "order" add constraint "order_customer_id_foreign" foreign key ("customer_id") references "customer" ("id") on update cascade;`);
    this.addSql(`alter table "order" add constraint "order_buyer_id_foreign" foreign key ("buyer_id") references "user" ("id") on update cascade on delete set null;`);
    this.addSql(`alter table "order_item" add constraint "order_item_order_id_foreign" foreign key ("order_id") references "order" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "order_item" add constraint "order_item_product_id_foreign" foreign key ("product_id") references "product" ("id") on update cascade;`);
    this.addSql(`alter table "coupon" add constraint "coupon_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "invoice" add constraint "invoice_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade;`);
    this.addSql(`alter table "invoice" add constraint "invoice_buyer_id_foreign" foreign key ("buyer_id") references "user" ("id") on update cascade on delete set null;`);
    this.addSql(`alter table "invoice" add constraint "invoice_order_id_foreign" foreign key ("order_id") references "order" ("id") on update cascade;`);
    this.addSql(`alter table "payout" add constraint "payout_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade;`);
    this.addSql(`alter table "ledger_entry" add constraint "ledger_entry_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade;`);
    this.addSql(`alter table "ledger_entry" add constraint "ledger_entry_payout_id_foreign" foreign key ("payout_id") references "payout" ("id") on update cascade on delete set null;`);
    this.addSql(`alter table "payout_job" add constraint "payout_job_payout_id_foreign" foreign key ("payout_id") references "payout" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "pickup_slot" add constraint "pickup_slot_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "pickup_booking" add constraint "pickup_booking_slot_id_foreign" foreign key ("slot_id") references "pickup_slot" ("id") on update cascade;`);
    this.addSql(`alter table "pickup_booking" add constraint "pickup_booking_order_id_foreign" foreign key ("order_id") references "order" ("id") on update cascade;`);
    this.addSql(`alter table "store_feed" add constraint "store_feed_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "webhook_delivery" add constraint "webhook_delivery_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
    this.addSql(`alter table "store_daily_stats" add constraint "store_daily_stats_store_id_foreign" foreign key ("store_id") references "store" ("id") on update cascade on delete cascade;`);
  }

  override async down(): Promise<void> {
    this.addSql('drop materialized view if exists "category_counts";');
    for (const table of [
      'store_feed', 'webhook_delivery', 'store_daily_stats', 'pickup_booking', 'pickup_slot', 'outbox_event', 'payout_job', 'ledger_entry', 'payout', 'invoice',
      'coupon', 'shipment', 'order_item', 'order', 'customer', 'product', 'brand', 'store_hours',
      'store_member', 'store', 'session', 'user_credential', 'user', 'category', 'country', 'platform_counters', 'cron_run',
    ]) {
      this.addSql(`drop table if exists "${table}" cascade;`);
    }
  }
}
