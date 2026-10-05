import { formatCents } from '../billing/money';

// Shows the plan prices of a currency from cheapest to most expensive.
export function PriceLadder({ planPrices, currency }: { planPrices: Record<string, number>; currency: string }) {
  const prices = Object.values(planPrices);
  prices.sort();
  return (
    <ol>
      {prices.map((cents) => (
        <li key={cents}>{formatCents(cents, currency)}</li>
      ))}
    </ol>
  );
}
