import { useEffect } from 'react';
import { Link } from 'react-router';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Dialog } from '../../components/Dialog';

/** The upsell dialog. The plan counts one "Upgrade Dialog Shown" per opening. */
export function UpgradeDialog({ open, source, onClose }: { open: boolean; source: string; onClose: () => void }) {
  const { trackEvent } = useTracking();
  useEffect(() => {
    if (open) trackEvent('Upgrade Dialog Shown', { source });
  }, [open, source, trackEvent]);

  return (
    <Dialog open={open} title="Get more from Shelfwise" onClose={onClose}>
      <p>Growth adds reports, two more stores and more seats.</p>
      <Link to="/billing/upgrade">See plans</Link>
    </Dialog>
  );
}
