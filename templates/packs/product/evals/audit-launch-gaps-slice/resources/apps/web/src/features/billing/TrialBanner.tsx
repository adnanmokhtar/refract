import { useMutation, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';

/** Shown in the last three days of a trial; one extension of 14 days per tenant. */
export function TrialBanner() {
  const qc = useQueryClient();
  const { trackEvent } = useTracking();
  const extend = useMutation({ mutationFn: () => http.post('billing/trial/extend').json() });

  async function extendTrial() {
    await extend.mutateAsync();
    trackEvent('Trial Extended', { day_count: 14 });
    void qc.invalidateQueries({ queryKey: ['session'] });
  }

  return (
    <aside className="trial-banner">
      Your trial ends soon.
      <Button variant="secondary" onClick={() => void extendTrial()}>
        Give me 14 more days
      </Button>
    </aside>
  );
}
