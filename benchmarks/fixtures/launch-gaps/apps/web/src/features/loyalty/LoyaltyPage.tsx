import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { http } from '../../shared/api/http';
import { flags } from '../../config/flags';
import { Button } from '../../components/Button';
import { LoyaltyTiersCard } from './LoyaltyTiersCard';

export function LoyaltyPage() {
  const { t } = useTranslation();
  const enable = useMutation({ mutationFn: () => http.post('loyalty/enable').json<{ enabled: boolean }>() });
  return (
    <section>
      <h1>{t('loyalty.title')}</h1>
      <p>Give customers one point per dollar and let them redeem points at the counter.</p>
      <Button onClick={() => enable.mutate()} disabled={enable.isPending}>
        {t('loyalty.enable')}
      </Button>
      {enable.isError && <p role="alert">Loyalty points could not be turned on.</p>}
      {flags.loyaltyTiers && <LoyaltyTiersCard />}
    </section>
  );
}
