'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

type Promo = { id: string; text: string; href: string };

export function PromoBanner() {
  const [promo, setPromo] = useState<Promo | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    api
      .get<Promo | null>('/promos/current', { signal: controller.signal })
      .then(setPromo)
      .catch(() => setPromo(null));
    return () => controller.abort();
  }, []);

  if (!promo) return null;

  return (
    <div className="bg-amber-100 py-3 text-center text-sm">
      <Link href={promo.href} className="underline underline-offset-4">
        {promo.text}
      </Link>
    </div>
  );
}
