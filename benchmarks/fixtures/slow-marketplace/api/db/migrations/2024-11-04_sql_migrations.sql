-- Bookkeeping for the hand-written SQL in this directory (see deploy/k8s/sql-migrate-job.yaml).
create table if not exists sql_migrations (
  name        text primary key,
  applied_at  timestamptz not null default now()
);
