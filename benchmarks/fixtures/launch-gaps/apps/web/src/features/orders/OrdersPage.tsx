import { Form, Link, useSearchParams } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { OrdersToolbar } from './OrdersToolbar';
import { AdvancedFilters } from './AdvancedFilters';
import { NewOrderForm } from './NewOrderForm';

interface OrderRow {
  id: string;
  number: string;
  customer: string;
  totalCents: number;
  status: 'paid' | 'refunded' | 'partially_refunded' | 'open';
}

export function OrdersPage() {
  const [params] = useSearchParams();
  const q = params.get('q') ?? '';
  const orders = useQuery({
    queryKey: ['orders', q],
    queryFn: () => http.get('orders', { searchParams: { q } }).json<{ items: OrderRow[] }>(),
  });
  return (
    <section>
      <h1>Orders</h1>
      <Form action="/search">
        <input name="q" defaultValue={q} placeholder="Order number or customer" />
      </Form>
      <AdvancedFilters />
      <OrdersToolbar selected={[]} />
      <NewOrderForm />
      <table>
        <tbody>
          {(orders.data?.items ?? []).map((o) => (
            <tr key={o.id}>
              <td>
                <Link to={`/orders/${o.id}`}>{o.number}</Link>
              </td>
              <td>{o.customer}</td>
              <td>{(o.totalCents / 100).toFixed(2)}</td>
              <td>{o.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
