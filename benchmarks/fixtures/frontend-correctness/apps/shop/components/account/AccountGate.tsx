'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useProfile } from '@/lib/queries';

export function AccountGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { data: session, isPending } = useProfile();

  useEffect(() => {
    if (!session && !isPending) router.replace('/login');
  }, [session, isPending, router]);

  return <>{children}</>;
}
