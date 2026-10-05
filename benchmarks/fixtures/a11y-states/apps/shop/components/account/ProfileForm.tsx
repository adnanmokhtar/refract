'use client';

import { useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { api } from '@/lib/api';
import { Button } from '@/components/ui/Button';

type Profile = { name: string; email: string; phone: string; bio: string };

export function ProfileForm({ initial }: { initial?: Partial<Profile> }) {
  const t = useTranslations('checkout');
  const tc = useTranslations('common');
  const {
    register,
    handleSubmit,
    reset,
    formState: { isDirty, errors },
  } = useForm<Profile>({ defaultValues: initial, mode: 'onBlur' });

  const save = useMutation({
    mutationFn: (values: Profile) => api.put('/me/profile', values),
    onSuccess: (_, values) => {
      reset(values);
      toast.success(tc('saved'));
    },
  });

  return (
    <form className="space-y-5" onSubmit={handleSubmit((values) => save.mutate(values))} noValidate>
      <div>
        <label htmlFor="profile-email" className="block text-sm font-medium">
          {t('email')}
        </label>
        <input
          id="profile-email"
          type="email"
          autoComplete="email"
          aria-invalid={errors.email ? true : undefined}
          aria-describedby={errors.email ? 'profile-email-error' : undefined}
          className="mt-1 h-11 w-full rounded-lg border px-3 focus-visible:ring-2 focus-visible:ring-ring"
          {...register('email', { required: t('email') })}
        />
        {errors.email && (
          <p id="profile-email-error" className="mt-1 text-sm text-destructive">
            {errors.email.message}
          </p>
        )}
      </div>
      <div>
        <label htmlFor="profile-bio" className="block text-sm font-medium">
          {t('contact')}
        </label>
        <textarea id="profile-bio" rows={4} className="mt-1 w-full rounded-lg border p-3" {...register('bio')} />
      </div>
      <Button type="submit" disabled={!isDirty || save.isPending} busy={save.isPending}>
        {tc('save')}
      </Button>
    </form>
  );
}
