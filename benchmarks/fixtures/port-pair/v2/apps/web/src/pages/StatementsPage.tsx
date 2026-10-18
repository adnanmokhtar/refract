import { useTranslation } from 'react-i18next';

export function StatementsPage() {
  const { t } = useTranslation();
  return <main><h1>{t('nav.StatementsPage')}</h1></main>;
}
