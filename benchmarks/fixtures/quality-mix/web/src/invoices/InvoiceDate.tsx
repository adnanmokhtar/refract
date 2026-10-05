// Display only: the issue date in the reader's own locale and zone, next to the invoice number.
export function InvoiceDate({ issuedAt }: { issuedAt: string }) {
  return <time dateTime={issuedAt}>{new Date(issuedAt).toLocaleDateString()}</time>;
}
