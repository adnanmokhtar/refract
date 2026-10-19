-- Core commerce schema.
create table stores (
  id text primary key,
  name text not null,
  tax_country char(2) not null,
  prices_include_tax boolean not null default false,
  timezone text not null default 'UTC',
  currency char(3) not null,
  vat_number text
);

create table customers (
  id text primary key,
  store_id text not null references stores(id),
  email text not null,
  name text not null
);

create table product_variants (
  id text primary key,
  sku text not null unique,
  title text not null,
  price bigint not null,
  stock_on_hand integer not null default 0
);

create table orders (
  id text primary key,
  store_id text not null references stores(id),
  customer_id text not null references customers(id),
  currency char(3) not null,
  subtotal_minor bigint not null,
  discount_minor bigint,
  discount_type text check (discount_type in ('fixed', 'percentage')),
  discount_value numeric(12, 2),
  shipping_minor bigint not null default 0,
  tax_minor bigint not null default 0,
  total_minor bigint not null,
  commission_minor bigint not null default 0,
  fee_minor bigint not null default 0,
  fx_rate numeric(18, 8),
  fx_rate_at timestamptz,
  fx_source text,
  status text not null default 'pending_payment'
    check (status in ('pending_payment', 'paid', 'fulfilling', 'shipped', 'delivered', 'cancelled', 'refunded', 'disputed', 'awaiting_review')),
  livemode boolean not null default true,
  paid_at timestamptz,
  confirmed_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create table order_items (
  id text primary key,
  order_id text not null references orders(id),
  product_id text not null references product_variants(id),
  quantity integer not null check (quantity > 0),
  unit_price_minor bigint not null,
  discount_alloc_minor bigint not null default 0,
  tax_rate_bp integer not null default 0,
  tax_minor bigint not null default 0,
  currency char(3) not null
);

create table payments (
  id text primary key,
  order_id text not null references orders(id),
  amount_minor bigint not null,
  currency char(3) not null,
  status text not null default 'pending',
  livemode boolean not null default true,
  created_at timestamptz not null default now()
);

create sequence invoice_number_seq;

create table invoices (
  id text primary key,
  order_id text not null references orders(id),
  customer_id text not null references customers(id) on delete cascade,
  number bigint not null default nextval('invoice_number_seq'),
  status text not null default 'draft',
  currency char(3) not null,
  net_minor bigint not null,
  tax_minor bigint not null,
  total_minor bigint not null,
  issued_at timestamptz,
  lines jsonb not null
);

create table credit_notes (
  id bigserial primary key,
  original_invoice_id text references invoices(id),
  amount_minor bigint not null,
  reason text not null,
  issued_at timestamptz not null
);

create table tax_rates (
  country char(2) not null,
  rate_bp integer not null,
  valid_from date not null,
  valid_to date,
  primary key (country, valid_from)
);

create table gift_cards (
  code text primary key,
  currency char(3) not null,
  balance_minor bigint not null
);

create table shipments (
  id text primary key,
  store_id text not null references stores(id),
  order_id text not null references orders(id),
  carrier text not null,
  shipped_at timestamptz,
  delivered_at timestamptz
);
