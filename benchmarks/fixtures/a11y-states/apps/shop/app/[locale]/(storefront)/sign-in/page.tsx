import { getTranslations, setRequestLocale } from 'next-intl/server';
import { SignInForm } from '@/components/auth/SignInForm';
import { OtpForm } from '@/components/auth/OtpForm';

export async function generateMetadata() {
  const t = await getTranslations('auth');
  return { title: t('signIn') };
}

export default async function SignInPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ step?: string }>;
}) {
  const { locale } = await params;
  const { step } = await searchParams;
  setRequestLocale(locale);
  const t = await getTranslations('auth');

  return (
    <div className="mx-auto mt-16 max-w-sm">
      <h1 className="text-2xl font-semibold">{t('signIn')}</h1>
      {step === 'code' ? <OtpForm /> : <SignInForm />}
    </div>
  );
}
