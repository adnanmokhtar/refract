import { useState } from 'react';
import { Button } from '@acme/ui';
import { t } from '@acme/i18n';
import { toast } from 'sonner';
import styles from './Checkout.module.css';
import { usePayment } from './usePayment';
import { couponCode, formatMoney } from './utils';

export function CheckoutPage() {
  const [coupon, setCoupon] = useState('');
  const pay = usePayment();

  async function submit() {
    try {
      await pay.mutateAsync({ coupon });
    } catch {
      toast.error(t('checkout.failed'));
    }
  }

  return (
    <section className={styles.checkout}>
      <p>{formatMoney(pay.totalMinor, pay.currency)}</p>
      <input value={coupon} onChange={(e) => setCoupon(e.target.value)} aria-label={t('checkout.coupon')} />
      <button type="button" className={styles.apply} onClick={() => setCoupon(couponCode(coupon))}>
        {t('checkout.apply')}
      </button>
      <Button onClick={submit}>{t('checkout.pay')}</Button>
    </section>
  );
}
