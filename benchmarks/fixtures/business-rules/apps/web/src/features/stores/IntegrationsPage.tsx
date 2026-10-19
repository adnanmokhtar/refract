import { useParams } from 'react-router';
import { http } from '../../shared/api/http';

export function IntegrationsPage() {
  const { storeId } = useParams();
  const connect = (channel: string) => http.post(`stores/${storeId}/integrations`, { json: { channel } });
  const connectCarrier = (carrier: string, apiKey: string) =>
    http.post(`stores/${storeId}/carriers/connect`, { json: { carrier, apiKey } });
  return (
    <section>
      <h1>Sales channels</h1>
      <button onClick={() => connect('marketplace')}>Connect a marketplace</button>
      <button onClick={() => connectCarrier('parcelwing', prompt('API key') ?? '')}>Use my own courier account</button>
    </section>
  );
}
