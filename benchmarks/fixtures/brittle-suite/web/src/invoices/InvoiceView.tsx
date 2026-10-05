import { useEffect, useState } from 'react';
import { fetchInvoice, formatMoney, InvoiceDto } from '../api/invoices';

export function InvoiceView({ invoiceId }: { invoiceId: string }) {
  const [invoice, setInvoice] = useState<InvoiceDto | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchInvoice(invoiceId)
      .then((inv) => !cancelled && setInvoice(inv))
      .catch((e: Error) => !cancelled && setError(e.message));
    return () => {
      cancelled = true;
    };
  }, [invoiceId]);

  if (error) return <p role="alert">Could not load the invoice: {error}</p>;
  if (!invoice) return <p aria-busy="true">Loading invoice…</p>;

  const subtotal = invoice.lines.reduce((sum, l) => sum + l.quantity * l.unitCents, 0);
  return (
    <article aria-labelledby="invoice-title" className="invoice">
      <header className="invoice__header">
        <h1 id="invoice-title">Invoice {invoice.number}</h1>
        <p className="invoice__meta">Currency: {invoice.currency}</p>
      </header>
      <table className="invoice__lines">
        <thead>
          <tr>
            <th scope="col">Item</th>
            <th scope="col">Qty</th>
            <th scope="col">Unit price</th>
            <th scope="col">Line total</th>
          </tr>
        </thead>
        <tbody>
          {invoice.lines.map((line) => (
            <tr key={line.description}>
              <td>{line.description}</td>
              <td>{line.quantity}</td>
              <td>{formatMoney(line.unitCents, invoice.currency)}</td>
              <td>{formatMoney(line.quantity * line.unitCents, invoice.currency)}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <th scope="row" colSpan={3}>Subtotal</th>
            <td>{formatMoney(subtotal, invoice.currency)}</td>
          </tr>
          <tr>
            <th scope="row" colSpan={3}>Total due</th>
            <td data-testid="invoice-total">{formatMoney(invoice.totalCents, invoice.currency)}</td>
          </tr>
        </tfoot>
      </table>
    </article>
  );
}
