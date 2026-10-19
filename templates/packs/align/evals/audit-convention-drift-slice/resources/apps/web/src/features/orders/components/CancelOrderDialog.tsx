import { Root as DialogRoot } from '@radix-ui/react-dialog';
import { Button, Can, DialogContent, DialogTitle } from '@acme/ui';
import { t } from '@acme/i18n';
import { toast } from 'sonner';
import { useCancelOrder } from '../useOrders';

type CancelOrderDialogProps = { orderId: string; isOpen: boolean; onOpenChange: (isOpen: boolean) => void };

export function CancelOrderDialog({ orderId, isOpen, onOpenChange }: CancelOrderDialogProps) {
  const cancel = useCancelOrder();

  async function confirm() {
    try {
      await cancel.mutateAsync(orderId);
      onOpenChange(false);
    } catch {
      toast.error(t('orders.errors.cancelFailed'));
    }
  }

  return (
    <DialogRoot open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogTitle>{t('orders.actions.cancel')}</DialogTitle>
        <Can action="orders.cancel">
          <Button variant="danger" onClick={confirm}>
            {t('orders.actions.cancel')}
          </Button>
        </Can>
      </DialogContent>
    </DialogRoot>
  );
}
