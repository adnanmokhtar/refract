import { useInvoices } from './useInvoices';
import { InvoiceDate } from './InvoiceDate';
import { formatCents } from '../billing/money';

export function InvoicesPage({ customerId }: { customerId: string }) {
  const { rows, loading } = useInvoices(customerId);
  if (loading) return <p aria-busy="true">Loading invoices…</p>;
  if (rows.length === 0) return <p>You have no invoices yet.</p>;
  return (
    <table>
      <tbody>
        {rows.map((r) => (
          <tr key={r.id}>
            <td>{r.number}</td>
            <td>
              <InvoiceDate issuedAt={r.issuedAt} />
            </td>
            <td>{formatCents(r.totalCents, 'EUR')}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
