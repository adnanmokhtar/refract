import { computeTax } from './tax-preview';
import { formatCents } from '../billing/money';

export function CheckoutSummary(props: { netCents: number; country: string; vatId?: string; currency: string }) {
  const taxCents = computeTax({ netCents: props.netCents, country: props.country, sellerCountry: 'DE', b2bVatId: props.vatId });
  return (
    <dl>
      <dt>Subtotal</dt>
      <dd>{formatCents(props.netCents, props.currency)}</dd>
      <dt>VAT</dt>
      <dd>{formatCents(taxCents, props.currency)}</dd>
      <dt>Total</dt>
      <dd>{formatCents(props.netCents + taxCents, props.currency)}</dd>
    </dl>
  );
}
