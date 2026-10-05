'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { api, ApiError } from '@/lib/api';
import { Button } from '@/components/ui/Button';

export function SignInForm() {
  const t = useTranslations('auth');
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(form: FormData) {
    setSubmitting(true);
    setError(null);
    try {
      await api.post('/auth/sign-in', { email: form.get('email'), password: form.get('password') });
      router.push('/sign-in?step=code');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t('signIn'));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form action={onSubmit} className="mt-6 space-y-5" aria-describedby={error ? 'signin-error' : undefined}>
      <div>
        <label htmlFor="signin-email" className="block text-sm font-medium">
          {t('email')}
        </label>
        <input id="signin-email" name="email" type="email" autoComplete="username" required className="mt-1 h-11 w-full rounded-lg border px-3" />
      </div>
      <div>
        <label htmlFor="signin-password" className="block text-sm font-medium">
          {t('password')}
        </label>
        <input
          id="signin-password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          onPaste={(e) => e.preventDefault()}
          className="mt-1 h-11 w-full rounded-lg border px-3"
        />
      </div>
      {error && (
        <p id="signin-error" role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
      <Button type="submit" className="w-full" disabled={submitting} busy={submitting}>
        {t('signIn')}
      </Button>
    </form>
  );
}
