'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useLocale, useTranslations } from 'next-intl';
import { WishlistButton } from './WishlistButton';
import { formatPrice } from '@/lib/format';
import type { Product } from '@/lib/api';

export function ProductCard({ product, onQuickAdd }: { product: Product; onQuickAdd: (id: string) => void }) {
  const t = useTranslations('product');
  const locale = useLocale();

  return (
    <article className="group relative">
      <Link href={`/products/${product.slug}`} className="block overflow-hidden rounded-card">
        <Image src={product.image} alt={product.name} width={480} height={600} className="h-auto w-full" />
      </Link>
      <WishlistButton productId={product.id} />
      <div
        className="absolute inset-x-3 bottom-20 hidden rounded-lg bg-background/95 py-2 text-center text-sm font-medium shadow group-hover:block"
        onClick={() => onQuickAdd(product.id)}
      >
        {t('quickAdd')}
      </div>
      <h3 className="mt-3 text-sm font-medium">
        <Link href={`/products/${product.slug}`}>{product.name}</Link>
      </h3>
      <p className="text-sm">{formatPrice(product.price, locale)}</p>
    </article>
  );
}
