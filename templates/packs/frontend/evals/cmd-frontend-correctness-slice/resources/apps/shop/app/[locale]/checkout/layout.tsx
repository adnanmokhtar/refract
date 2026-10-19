import { redirect } from 'next/navigation';
import { getSession } from '@/lib/server/account';

export default async function CheckoutLayout({ children }: { children: React.ReactNode }) {
  const session = await getSession().catch(() => null);
  if (!session) redirect('/login?returnTo=/checkout');
  return <>{children}</>;
}
