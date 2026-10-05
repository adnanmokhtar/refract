'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';
import { Button } from '@/components/ui/Button';

export function OtpForm() {
  const t = useTranslations('auth');
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(form: FormData) {
    setSubmitting(true);
    try {
      await api.post('/auth/verify', { code: form.get('code') });
      router.push('/account');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form action={onSubmit} className="mx-auto mt-6 w-[320px] space-y-5">
      <div>
        <label htmlFor="otp-code" className="block text-sm font-medium">
          {t('code')}
        </label>
        <input
          id="otp-code"
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="[0-9]{6}"
          maxLength={6}
          required
          className="mt-1 h-11 w-full rounded-lg border px-3 text-center tracking-widest"
        />
      </div>
      <Button type="submit" className="w-full" disabled={submitting} busy={submitting}>
        {t('verify')}
      </Button>
    </form>
  );
}
