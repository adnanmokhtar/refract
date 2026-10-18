import { Button } from '@acme/ui';
import { formatMoney } from '@acme/format';
import { t } from '@acme/i18n';

type OrderRowProps = { reference: string; totalMinor: number; currency: string; onOpen: () => void };

export function OrderRow({ reference, totalMinor, currency, onOpen }: OrderRowProps) {
  return (
    <tr>
      <td>{reference}</td>
      <td>{formatMoney(totalMinor, currency)}</td>
      <td>
        <Button variant="secondary" onClick={onOpen}>
          {t('orders.actions.open')}
        </Button>
      </td>
    </tr>
  );
}
