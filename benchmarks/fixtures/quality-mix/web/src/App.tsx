import { useState } from 'react';
import { useCurrentUser } from './account/useCurrentUser';
import { DisplayName } from './account/DisplayName';
import { InvoicesPage } from './invoices/InvoicesPage';
import { BillingPage } from './billing/BillingPage';
import { CheckoutSummary } from './checkout/CheckoutSummary';
import { DiscountOverrideInput } from './checkout/DiscountOverrideInput';
import { PriceLadder } from './pricing/PriceLadder';
import { SearchPage } from './search/SearchPage';
import { FinanceDashboard } from './reports/FinanceDashboard';
import { PlanChangeForm } from './subscriptions/PlanChangeForm';

type Tab = 'invoices' | 'billing' | 'checkout' | 'pricing' | 'search' | 'finance' | 'plan';

export function App() {
  const user = useCurrentUser();
  const [tab, setTab] = useState<Tab>('invoices');
  const [discount, setDiscount] = useState<number | undefined>(undefined);

  if (!user) return <a href="/login">Sign in</a>;
  return (
    <main>
      <header>
        <DisplayName displayName={user.name} />
        <nav>
          {(['invoices', 'billing', 'checkout', 'pricing', 'search', 'finance', 'plan'] as Tab[]).map((t) => (
            <button key={t} onClick={() => setTab(t)} aria-pressed={tab === t}>
              {t}
            </button>
          ))}
        </nav>
      </header>
      {tab === 'invoices' && <InvoicesPage customerId={user.id} />}
      {tab === 'billing' && <BillingPage customerId={user.id} />}
      {tab === 'checkout' && (
        <>
          <DiscountOverrideInput onChange={setDiscount} />
          <CheckoutSummary netCents={12_000 - 120 * (discount ?? 10)} country="DE" currency="EUR" />
        </>
      )}
      {tab === 'pricing' && <PriceLadder planPrices={{ starter: 1_900, growth: 9_900, enterprise: 49_900 }} currency="EUR" />}
      {tab === 'search' && <SearchPage />}
      {tab === 'finance' && <FinanceDashboard />}
      {tab === 'plan' && <PlanChangeForm />}
    </main>
  );
}
