import { useState } from 'react';
import { Button } from '@acme/ui';
import { setLocale, t } from '@acme/i18n';
import { toast } from 'sonner';
import { useSaveSettings } from './useSaveSettings';

interface SettingsFormProps {
  initialLocale: 'en' | 'ar';
}

export function SettingsForm({ initialLocale }: SettingsFormProps) {
  const [locale, setLocaleValue] = useState(initialLocale);
  const save = useSaveSettings();

  async function submit() {
    try {
      await save.mutateAsync({ locale });
      setLocale(locale);
    } catch {
      toast.error(t('settings.saveFailed'));
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
        {t('settings.language')}
        <select value={locale} onChange={(e) => setLocaleValue(e.target.value as 'en' | 'ar')}>
          <option value="en">{t('settings.languages.en')}</option>
          <option value="ar">{t('settings.languages.ar')}</option>
        </select>
      </label>
      <Button type="submit">Save</Button>
    </form>
  );
}
