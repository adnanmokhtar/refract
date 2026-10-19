import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';
import { DeleteStoreDialog } from '../settings/DeleteStoreDialog';

interface Store {
  id: string;
  name: string;
  type: 'shopify' | 'woocommerce' | 'manual';
  lastSyncedAt: string | null;
}

export function StoresPage() {
  const qc = useQueryClient();
  const { trackEvent } = useTracking();
  const stores = useQuery({ queryKey: ['stores'], queryFn: () => http.get('stores').json<Store[]>() });
  const sync = useMutation({
    mutationFn: (id: string) => http.post(`stores/${id}/sync`).json<{ synced: number }>(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['stores'] }),
  });
  const addManual = useMutation({
    mutationFn: () => http.post('stores', { json: { type: 'manual', name: 'Counter' } }).json<Store>(),
    onSuccess: () => {
      trackEvent('Store Connected', { store_type: 'manual', count: '1' });
      void qc.invalidateQueries({ queryKey: ['stores'] });
    },
  });

  return (
    <section>
      <h1>Stores</h1>
      <Button onClick={() => addManual.mutate()}>Add a counter store</Button>
      <ul>
        {(stores.data ?? []).map((s) => (
          <li key={s.id}>
            {s.name} · {s.type} · {s.lastSyncedAt ?? 'never synced'}
            <Button variant="secondary" onClick={() => sync.mutate(s.id)} disabled={sync.isPending}>
              Sync now
            </Button>
            <DeleteStoreDialog storeId={s.id} storeName={s.name} />
          </li>
        ))}
      </ul>
    </section>
  );
}
