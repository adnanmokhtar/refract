import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useModuleEnabled } from '../../shared/entitlements/use-module-enabled';
import { Button } from '../../components/Button';

/** Bulk import: upload a spreadsheet to the files service, then start an import job from it. */
export function ImportPage() {
  const enabled = useModuleEnabled('bulk_import');
  const template = useMutation({
    mutationFn: () => http.get('files/import-template/signed-url').json<{ url: string }>(),
    onSuccess: ({ url }) => window.open(url, '_blank'),
  });
  const start = useMutation({ mutationFn: (fileId: string) => http.post('imports', { json: { fileId, dryRun: true } }).json() });
  if (!enabled) return <p>Bulk import is part of the Scale plan.</p>;
  return (
    <section>
      <h1>Import products</h1>
      <Button variant="secondary" onClick={() => template.mutate()}>
        Download the template
      </Button>
      <input type="file" accept=".csv,.xlsx" onChange={(e) => e.target.files?.[0] && start.mutate(e.target.files[0].name)} />
    </section>
  );
}
