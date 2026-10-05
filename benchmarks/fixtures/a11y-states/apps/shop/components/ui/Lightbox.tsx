'use client';

import { useEffect, useRef } from 'react';
import Image from 'next/image';
import { X } from 'lucide-react';
import { useTranslations } from 'next-intl';

export function Lightbox({ src, alt, onClose }: { src: string; alt: string; onClose: () => void }) {
  const t = useTranslations('common');
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      previous?.focus();
    };
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4" onClick={onClose}>
      <figure className="relative max-h-full max-w-3xl" onClick={(e) => e.stopPropagation()}>
        <Image src={src} alt={alt} width={1200} height={1200} className="h-auto w-full rounded-lg" />
        <button
          ref={closeRef}
          type="button"
          aria-label={t('close')}
          onClick={onClose}
          className="absolute end-2 top-2 grid size-11 place-items-center rounded-full bg-background/90 focus-visible:ring-2 focus-visible:ring-ring"
        >
          <X aria-hidden className="size-5" />
        </button>
      </figure>
    </div>
  );
}
