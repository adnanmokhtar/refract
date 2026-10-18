// eslint-disable-next-line no-restricted-imports -- ADR-0007 streams PDFs; apiClient parses JSON
import ky from 'ky';

export async function downloadInvoicePdf(invoiceId: string, token: string): Promise<Blob> {
  const res = await ky.get(`/api/v2/invoices/${invoiceId}/pdf`, { headers: { authorization: `Bearer ${token}` } });
  return res.blob();
}
