import { useEffect, useState } from 'react';
import { http } from '../../shared/api/http';

type ApiKey = { id: string; label: string };

export function ApiKeysPage() {
  const [keys, setKeys] = useState<ApiKey[]>([]);
  useEffect(() => {
    http.get('api-keys').json<ApiKey[]>().then(setKeys);
  }, []);
  return (
    <section>
      <h1>API keys</h1>
      <button onClick={() => http.post('api-keys', { json: { label: 'storefront' } })}>New key</button>
      <ul>
        {keys.map((k) => (
          <li key={k.id}>{k.label}</li>
        ))}
      </ul>
    </section>
  );
}
