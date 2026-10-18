import { Migration } from '@mikro-orm/migrations';

// V1 wrote invoice_audit from InvoiceObserver::updated. V2 keeps the row in the database itself,
// so every writer (API, nightly job, backfill fix-ups) is audited the same way.
export class Migration20261002000000_invoice_audit extends Migration {
  async up(): Promise<void> {
    this.addSql(`create function invoice_audit_row() returns trigger language plpgsql as $$
      begin
        -- V1 stored $invoice->getChanges(): the changed columns only, and so does this. changed_by reads
        -- norrow.user_id when a writer sets it and is NULL otherwise (ADR-0014).
        insert into invoice_audit (invoice_id, changes, changed_by, changed_at)
        select new.id, jsonb_object_agg(n.key, n.value), nullif(current_setting('norrow.user_id', true), '')::bigint, now()
        from jsonb_each(to_jsonb(new)) n
        where n.key <> 'updated_at' and to_jsonb(old) -> n.key is distinct from n.value
        having count(*) > 0;
        return new;
      end $$;`);

    this.addSql('create trigger invoices_audit_trg after update on invoices for each row execute function invoice_audit_row();');
  }
}
