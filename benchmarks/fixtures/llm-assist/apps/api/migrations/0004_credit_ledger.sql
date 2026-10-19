-- AI credits: one wallet per account, one ledger row per debit source.
create table credit_wallets (
  account_id text primary key,
  balance integer not null check (balance >= 0)
);

create table credit_ledger (
  id uuid primary key,
  account_id text not null references credit_wallets(account_id),
  delta integer not null,
  source_key text not null,
  created_at timestamptz not null default now()
);

create unique index credit_ledger_source_key_uq on credit_ledger (source_key);
create index credit_ledger_account_idx on credit_ledger (account_id, created_at desc);

create table llm_usage (
  id uuid primary key,
  account_id text not null,
  prompt_tokens integer not null,
  completion_tokens integer not null,
  cost_micros bigint not null,
  created_at timestamptz not null default now()
);
