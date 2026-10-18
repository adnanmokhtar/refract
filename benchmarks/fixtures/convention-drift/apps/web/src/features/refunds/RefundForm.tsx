import { useState } from 'react';
import { Button, Can } from '@acme/ui';
import { t } from '@acme/i18n';
import { toast } from 'sonner';
import { useRequestRefund } from './useRequestRefund';

interface RefundFormProps {
  orderId: string;
  maxMinor: number;
}

export function RefundForm({ orderId, maxMinor }: RefundFormProps) {
  const [amount, setAmount] = useState(maxMinor);
  const [hasError, setHasError] = useState(false);
  const refund = useRequestRefund();

  async function submit() {
    try {
      await refund.mutateAsync({ orderId, amountMinor: amount });
      setHasError(false);
    } catch {
      setHasError(true);
      toast.error(t('refunds.failed'));
    }
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        void submit();
      }}
    >
      <label>
        {t('refunds.amount')}
        <input type="number" value={amount} max={maxMinor} onChange={(e) => setAmount(Number(e.target.value))} />
      </label>
      {hasError ? <p style={{ color: '#d92d20' }}>{t('refunds.failed')}</p> : null}
      <Can action="orders.refund">
        <Button type="submit">{t('refunds.submit')}</Button>
      </Can>
    </form>
  );
}
