import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';

type StoreType = 'shopify' | 'woocommerce' | 'manual';

export function ConnectStoreStep() {
  const navigate = useNavigate();
  const { trackEvent } = useTracking();
  const [form, setForm] = useState<{ type: StoreType; name: string }>({ type: 'shopify', name: '' });
  const connect = useMutation({ mutationFn: () => http.post('stores', { json: form }).json<{ id: string }>() });

  async function submit() {
    await connect.mutateAsync();
    trackEvent('StoreConnected', { store_type: form.type, count: 1 });
    navigate('/');
  }

  return (
    <section className="onboarding">
      <h1>Connect your first store</h1>
      <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value as StoreType })}>
        <option value="shopify">Shopify</option>
        <option value="woocommerce">WooCommerce</option>
        <option value="manual">Manual (counter sales only)</option>
      </select>
      <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
      <Button onClick={() => void submit()}>Connect</Button>
    </section>
  );
}
