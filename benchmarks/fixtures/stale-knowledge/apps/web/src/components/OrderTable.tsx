import type { OrderDto } from '@orderly/contracts';

export function OrderTable({ orders }: { orders: OrderDto[] }) {
  return (
    <table>
      <tbody>
        {orders.map((o) => (
          <tr key={o.id}>
            <td>{o.id}</td>
            <td>{o.status}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
