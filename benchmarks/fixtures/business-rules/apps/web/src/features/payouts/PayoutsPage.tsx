import { formatMoney } from '../../shared/format-money';
import { estimatedCommissionMinor } from './commission';

export function PayoutsPage({ salesMinor = 0, currency = 'USD' }: { salesMinor?: number; currency?: string }) {
  return (
    <section>
      <h1>Payouts</h1>
      <p>Estimated commission this month: {formatMoney(estimatedCommissionMinor(salesMinor), currency)}</p>
    </section>
  );
}
