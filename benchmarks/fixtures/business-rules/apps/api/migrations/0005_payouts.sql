create table payouts (
  id text primary key,
  wallet_id text not null references merchant_wallets(id),
  amount_minor bigint not null,
  currency char(3) not null,
  fee_amount double precision not null default 0,
  created_at timestamptz not null default now()
);

create table fee_schedules (
  id serial primary key,
  store_id text not null references stores(id),
  fee_rate numeric(9, 6) not null,
  valid_from timestamptz not null
);
