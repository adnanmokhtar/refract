import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { Button } from '../../components/Button';
import { ThemeToggle } from './ThemeToggle';

interface ApiKey {
  id: string;
  label: string;
  lastUsedAt: string | null;
}

export function SettingsPage() {
  const qc = useQueryClient();
  const keys = useQuery({ queryKey: ['api-keys'], queryFn: () => http.get('api-keys').json<ApiKey[]>() });
  const create = useMutation({
    mutationFn: (label: string) => http.post('api-keys', { json: { label } }).json<ApiKey & { secret: string }>(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['api-keys'] }),
  });
  return (
    <section>
      <h1>Settings</h1>
      <h2>Appearance</h2>
      <ThemeToggle />
      <h2>API keys</h2>
      <Button onClick={() => create.mutate('Storefront')}>Create key</Button>
      <ul>
        {(keys.data ?? []).map((k) => (
          <li key={k.id}>
            {k.label} · last used {k.lastUsedAt ?? 'never'}
          </li>
        ))}
      </ul>
    </section>
  );
}
