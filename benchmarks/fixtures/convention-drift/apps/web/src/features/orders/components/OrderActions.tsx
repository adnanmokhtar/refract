import { Button, Can } from '@acme/ui';
import { t } from '@acme/i18n';
import { toast } from 'sonner';
import { useArchiveOrder, useCancelOrder, useDeleteOrder } from '../useOrders';
import styles from './OrderActions.module.css';

type OrderActionsProps = { orderId: string };

export function OrderActions({ orderId }: OrderActionsProps) {
  const deletion = useDeleteOrder();
  const archive = useArchiveOrder();
  const cancel = useCancelOrder();

  async function deleteOrder() {
    try {
      await deletion.mutateAsync(orderId);
    } catch {
      toast.error(t('orders.errors.deleteFailed'));
    }
  }

  return (
    <div className={styles.actions}>
      <Can action="orders.cancel">
        <Button variant="secondary" onClick={() => cancel.mutate(orderId)}>
          {t('orders.actions.cancel')}
        </Button>
      </Can>
      <Button variant="danger" onClick={deleteOrder}>
        {t('orders.actions.delete')}
      </Button>
      <Button variant="secondary" onClick={() => archive.mutate(orderId)}>
        Archive order
      </Button>
    </div>
  );
}
