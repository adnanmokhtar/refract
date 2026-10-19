import { useState } from 'react';
import { useSession } from '../../shared/session/use-session';
import { UpgradeDialog } from './UpgradeDialog';

export function PlanBadge() {
  const plan = useSession().data?.plan;
  const [open, setOpen] = useState(false);
  if (!plan) return null;
  return (
    <>
      <button type="button" className="plan-badge" onClick={() => setOpen(true)}>
        {plan}
      </button>
      <UpgradeDialog open={open} source="plan-badge" onClose={() => setOpen(false)} />
    </>
  );
}
