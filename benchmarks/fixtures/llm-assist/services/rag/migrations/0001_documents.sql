create extension if not exists vector;

create table documents (
  id uuid primary key,
  tenant_id text not null,
  title text not null,
  product text,
  visibility text not null default 'all_agents' check (visibility in ('all_agents', 'admins_only', 'public')),
  allowed_groups text[] not null default '{}',
  summary text,
  created_at timestamptz not null default now()
);

create table usage_events (
  id bigserial primary key,
  tenant_id text not null,
  input_tokens integer not null,
  output_tokens integer not null,
  cost_eur numeric(12, 6) not null,
  created_at timestamptz not null default now()
);
