-- General ledger. Every entry balances per currency; enforced at COMMIT for every writer.
create table gl_journal_entries (
  id uuid primary key,
  source_type text not null,
  source_id text not null,
  entry_date timestamptz not null,
  status text not null default 'posted',
  reversal_of uuid references gl_journal_entries(id),
  reconciled_at timestamptz,
  statement_line_id text
);

create index gl_journal_entries_source_idx on gl_journal_entries (source_type, source_id);

create table gl_journal_lines (
  id bigserial primary key,
  entry_id uuid not null references gl_journal_entries(id),
  account_code text not null,
  currency char(3) not null,
  debit_minor bigint not null default 0 check (debit_minor >= 0),
  credit_minor bigint not null default 0 check (credit_minor >= 0),
  check ((debit_minor = 0) <> (credit_minor = 0))
);

create function gl_assert_entry_balanced() returns trigger language plpgsql as $$
begin
  if exists (
    select 1 from gl_journal_lines
     where entry_id = new.entry_id
     group by currency
    having sum(debit_minor) <> sum(credit_minor)
  ) then
    raise exception 'journal entry % does not balance', new.entry_id;
  end if;
  return null;
end $$;

create constraint trigger gl_journal_lines_entry_balances
  after insert or update on gl_journal_lines
  deferrable initially deferred
  for each row execute function gl_assert_entry_balanced();
