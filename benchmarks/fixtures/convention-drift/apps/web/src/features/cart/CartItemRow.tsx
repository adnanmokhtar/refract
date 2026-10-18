import { IconButton, TrashIcon, notify } from '@acme/ui';
import { formatMoney } from '@acme/format';
import { t } from '@acme/i18n';
import { type CartItem, drop, useAppDispatch } from './cart-store';

interface CartItemRowProps {
  item: CartItem;
  currency: string;
}

export function CartItemRow({ item, currency }: CartItemRowProps) {
  const dispatch = useAppDispatch();

  function onDrop() {
    try {
      dispatch(drop(item.sku));
    } catch {
      notify({ kind: 'error', message: t('cart.updateFailed') });
    }
  }

  return (
    <li>
      {item.name} × {item.quantity} · {formatMoney(item.priceMinor * item.quantity, currency)}
      <IconButton icon={TrashIcon} onClick={onDrop} />
    </li>
  );
}
