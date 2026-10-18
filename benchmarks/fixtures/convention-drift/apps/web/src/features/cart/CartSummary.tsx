import { connect } from 'react-redux';
import { Button } from '@acme/ui';
import { formatMoney } from '@acme/format';
import { t } from '@acme/i18n';
import { toast } from 'sonner';
import styles from './Cart.module.css';
import type { RootState } from './cart-store';

type CartSummaryProps = { totalMinor: number; currency: string; onCheckout: () => Promise<void> };

function CartSummaryView({ totalMinor, currency, onCheckout }: CartSummaryProps) {
  async function checkout() {
    try {
      await onCheckout();
    } catch {
      toast.error(t('cart.checkoutFailed'));
    }
  }

  return (
    <div className={styles.summary}>
      <span>{formatMoney(totalMinor, currency)}</span>
      <Button onClick={checkout}>{t('checkout.pay')}</Button>
    </div>
  );
}

const mapState = (state: RootState) => ({
  totalMinor: state.cart.items.reduce((sum, i) => sum + i.priceMinor * i.quantity, 0),
  currency: state.cart.currency,
});

export const CartSummary = connect(mapState)(CartSummaryView);
