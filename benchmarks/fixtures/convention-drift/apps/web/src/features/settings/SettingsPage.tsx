import { t } from '@acme/i18n';
import { SettingsForm } from './SettingsForm';

export default function SettingsPage() {
  return (
    <section>
      <h1>{t('settings.title')}</h1>
      <SettingsForm initialLocale="en" />
    </section>
  );
}
