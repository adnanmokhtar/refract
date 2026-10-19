'use client';

import { useForm } from 'react-hook-form';
import { useTranslations } from 'next-intl';

type Contact = { email: string; phone: string };

export function ContactForm() {
  const t = useTranslations('checkout');
  const {
    register,
    formState: { errors },
  } = useForm<Contact>({ mode: 'onBlur' });

  return (
    <div className="mt-6 space-y-5">
      <div>
        <label htmlFor="checkout-email" className="block text-sm font-medium">
          {t('email')}
        </label>
        <input
          id="checkout-email"
          type="email"
          autoComplete="email"
          className="mt-1 h-11 w-full rounded-lg border px-3 focus-visible:ring-2 focus-visible:ring-ring"
          {...register('email', { required: t('email') })}
        />
        {errors.email && <p className="mt-1 text-sm text-destructive">{errors.email.message}</p>}
      </div>
      <div>
        <label htmlFor="checkout-phone" className="block text-sm font-medium">
          {t('phone')}
        </label>
        <input
          id="checkout-phone"
          type="tel"
          autoComplete="tel"
          className="mt-1 h-11 w-full rounded-lg border px-3 focus-visible:ring-2 focus-visible:ring-ring"
          {...register('phone')}
        />
      </div>
    </div>
  );
}
