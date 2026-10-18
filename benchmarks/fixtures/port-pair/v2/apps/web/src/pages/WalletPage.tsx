import { useTranslation } from 'react-i18next';

export function WalletPage() {
  const { t } = useTranslation();
  return <main><h1>{t('nav.WalletPage')}</h1></main>;
}
