create table merchant_wallets (
  id text primary key,
  currency char(3) not null,
  balance_minor bigint not null default 0,
  available_minor bigint not null default 0
);

create table wallet_transactions (
  id uuid primary key,
  wallet_id text not null,
  amount_minor bigint not null,
  currency char(3) not null,
  kind text not null,
  source_type text not null,
  source_id text not null,
  leg smallint not null default 0,
  customer_email text,
  created_at timestamptz not null default now()
);

create unique index wallet_transactions_source_uq on wallet_transactions (source_type, source_id, leg);

create table couriers (
  id text primary key,
  name text not null,
  cod_balance_minor bigint not null default 0
);

create table courier_cod_entries (
  id bigserial primary key,
  courier_id text not null references couriers(id),
  order_id text not null,
  amount_minor bigint not null,
  created_at timestamptz not null default now()
);
