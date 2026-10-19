import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Button } from '../../components/Button';

export function WelcomePage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  return (
    <section className="onboarding">
      <h1>{t('onboarding.welcome.title')}</h1>
      <p>Connect a Shopify or WooCommerce store, or start with a manual one.</p>
      <Button onClick={() => navigate('/onboarding/connect-store')}>{t('onboarding.welcome.cta')}</Button>
    </section>
  );
}
