import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { BILLING_PLANS, CURRENCY } from '@shelfwise/config';
import { PLAN_KEYS, type PlanKey } from '@shelfwise/contracts';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { ENABLE_NEW_CHECKOUT } from '../../config/flags';
import { Button } from '../../components/Button';
import { CouponField } from './CouponField';
import { LegacyUpgrade } from './LegacyUpgrade';
import { PlanCompareDialog } from './PlanCompareDialog';

export function UpgradePage() {
  const { trackEvent } = useTracking();
  const [compareOpen, setCompareOpen] = useState(false);
  const createCheckout = useMutation({ mutationFn: (plan: PlanKey) => http.post('billing/checkout', { json: { plan } }).json<{ url: string }>() });

  // Creates the Stripe Checkout session and sends the merchant to Stripe to pay.
  async function startUpgrade(plan: PlanKey) {
    const session = await createCheckout.mutateAsync(plan);
    trackEvent('Plan Purchased', { plan, value: BILLING_PLANS[plan].displayPrice, currency: CURRENCY });
    window.location.assign(session.url);
  }

  if (!ENABLE_NEW_CHECKOUT) return <LegacyUpgrade />;
  return (
    <section>
      <h1>Choose your plan</h1>
      <Button variant="secondary" onClick={() => setCompareOpen(true)}>
        Compare plans
      </Button>
      <PlanCompareDialog open={compareOpen} onClose={() => setCompareOpen(false)} />
      <CouponField />
      <ul className="plans">
        {PLAN_KEYS.map((p) => (
          <li key={p}>
            <h2>{p}</h2>
            <Button
              disabled={createCheckout.isPending}
              onClick={() => {
                trackEvent('Checkout Started', { plan: p });
                void startUpgrade(p);
              }}
            >
              Upgrade to {p}
            </Button>
          </li>
        ))}
      </ul>
    </section>
  );
}
