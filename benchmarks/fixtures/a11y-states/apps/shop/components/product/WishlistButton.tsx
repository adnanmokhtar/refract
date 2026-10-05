'use client';

import { Heart } from 'lucide-react';
import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';
import { Toast } from '@/components/ui/Toast';

export function WishlistButton({ productId, initial = false }: { productId: string; initial?: boolean }) {
  const t = useTranslations('product');
  const [saved, setSaved] = useState(initial);
  const [notice, setNotice] = useState<string | null>(null);

  async function toggle() {
    const next = !saved;
    setSaved(next);
    try {
      await api.post(`/me/wishlist/${productId}/toggle`, { saved: next });
      if (next) setNotice(t('wishlist'));
    } catch {
      setSaved(!next);
    }
  }

  return (
    <>
      <button
        type="button"
        onClick={toggle}
        aria-pressed={saved}
        className="absolute end-3 top-3 grid size-11 place-items-center rounded-full bg-background/90 focus-visible:ring-2 focus-visible:ring-ring"
      >
        <Heart className={saved ? 'size-5 fill-current text-destructive' : 'size-5'} />
      </button>
      <Toast message={notice} onDone={() => setNotice(null)} />
    </>
  );
}
