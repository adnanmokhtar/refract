import { useLoaderData } from 'react-router';
import { api } from '../lib/api';

interface OrderRow {
  orderId: string;
  status: string;
}

/** The merchant's order list: GET /api/orders/summary, served from order_summary (the projected read model). */
export async function loader(): Promise<OrderRow[]> {
  return api.get<OrderRow[]>('/orders/summary');
}

export default function Orders(): JSX.Element {
  const rows = useLoaderData() as OrderRow[];
  return (
    <table>
      <tbody>
        {rows.map((r) => (
          <tr key={r.orderId}><td>{r.orderId}</td><td>{r.status}</td></tr>
        ))}
      </tbody>
    </table>
  );
}
