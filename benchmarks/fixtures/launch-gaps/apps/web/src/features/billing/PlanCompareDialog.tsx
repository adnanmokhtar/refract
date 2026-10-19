import { useEffect } from 'react';
import { BILLING_PLANS } from '@shelfwise/config';
import { PLAN_KEYS } from '@shelfwise/contracts';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Dialog } from '../../components/Dialog';

export function PlanCompareDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { trackEvent } = useTracking();
  useEffect(() => {
    if (open) trackEvent('Pricing Table Viewed', { source: 'upgrade-page' });
  }, [open, onClose, trackEvent]);

  return (
    <Dialog open={open} title="Compare plans" onClose={onClose}>
      <table>
        <tbody>
          {PLAN_KEYS.map((p) => (
            <tr key={p}>
              <th>{p}</th>
              <td>{BILLING_PLANS[p].maxSeats} seats</td>
              <td>{BILLING_PLANS[p].maxStores ?? 'Unlimited'} stores</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Dialog>
  );
}
