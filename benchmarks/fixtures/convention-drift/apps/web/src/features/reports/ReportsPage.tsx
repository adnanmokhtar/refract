import { useEffect } from 'react';
import { notify } from '@acme/ui';
import { t } from '@acme/i18n';
import { ReportTable } from '@acme/legacy-reports';
import { useReports } from './useReports';

export function ReportsPage() {
  const { data, error } = useReports();

  useEffect(() => {
    if (error) notify({ kind: 'error', message: t('reports.loadFailed') });
  }, [error]);

  return (
    <section>
      <h1>{t('reports.title')}</h1>
      <ReportTable rows={data ?? []} />
    </section>
  );
}
