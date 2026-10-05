'use client';

import Image from 'next/image';
import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { Lightbox } from '@/components/ui/Lightbox';

export function ProductGallery({ name, images }: { name: string; images: string[] }) {
  const t = useTranslations('product');
  const [active, setActive] = useState(0);
  const [zoomed, setZoomed] = useState(false);

  return (
    <div>
      <button
        type="button"
        tabIndex={1}
        aria-label={`${name} — ${t('details')}`}
        onClick={() => setZoomed(true)}
        className="block w-full overflow-hidden rounded-card focus-visible:ring-2 focus-visible:ring-ring"
      >
        <Image src={images[active]} alt="" width={900} height={1100} priority className="h-auto w-full" />
      </button>
      <ul className="mt-3 flex gap-2">
        {images.map((src, i) => (
          <li key={src}>
            <button
              type="button"
              aria-label={`${name} ${i + 1}`}
              aria-current={i === active}
              onClick={() => setActive(i)}
              className="block size-16 overflow-hidden rounded-lg border focus-visible:ring-2 focus-visible:ring-ring"
            >
              <Image src={src} alt="" width={64} height={64} className="size-full object-cover" />
            </button>
          </li>
        ))}
      </ul>
      {zoomed && <Lightbox src={images[active]} alt={name} onClose={() => setZoomed(false)} />}
    </div>
  );
}
