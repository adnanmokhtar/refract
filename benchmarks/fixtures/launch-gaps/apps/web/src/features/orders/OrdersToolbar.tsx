import { Button } from '../../components/Button';
import { useCan } from '../../entities/permissions/use-permissions';

export function OrdersToolbar({ selected }: { selected: string[] }) {
  const canRefund = useCan('orders.refund');
  return (
    <div className="toolbar" role="toolbar" aria-label="Order actions">
      <Button variant="secondary" onClick={() => window.print()}>
        Print list
      </Button>
      <Button variant="secondary" onClick={() => {}}>
        Print packing slips
      </Button>
      {canRefund && selected.length > 0 && <span>{selected.length} selected</span>}
    </div>
  );
}
