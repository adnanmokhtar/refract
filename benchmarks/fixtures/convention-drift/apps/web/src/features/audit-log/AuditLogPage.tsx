import { useEffect } from 'react';
import { DataTable, notify } from '@acme/ui';
import type { Column } from '@acme/ui';
import { t } from '@acme/i18n';
import { type AuditEntry, useAuditLog } from './useAuditLog';

// Read-only: audit entries are immutable, and nobody deletes them from the UI.
const columns: Column<AuditEntry>[] = [
  { key: 'at', header: t('audit.columns.at') },
  { key: 'actor', header: t('audit.columns.actor') },
  { key: 'action', header: t('audit.columns.action') },
];

export function AuditLogPage() {
  const { data, error } = useAuditLog();

  useEffect(() => {
    if (error) notify({ kind: 'error', message: t('audit.loadFailed') });
  }, [error]);

  return (
    <section>
      <h1>{t('audit.title')}</h1>
      <DataTable rows={data ?? []} columns={columns} />
    </section>
  );
}
