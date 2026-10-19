create table order_status_history (
  id bigserial primary key,
  order_id text not null references orders(id),
  "from" text not null,
  "to" text not null,
  actor text not null,
  at timestamptz not null default now()
);

create table seat_subscriptions (
  id text primary key,
  store_id text not null references stores(id),
  anchor_date timestamptz not null,
  cycles_billed integer not null default 0,
  current_period_start timestamptz not null,
  current_period_end timestamptz not null
);
