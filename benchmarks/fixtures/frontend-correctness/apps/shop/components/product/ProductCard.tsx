import Image from 'next/image';
import Link from 'next/link';
import type { Product } from '@/lib/api';
import { PriceTag } from './PriceTag';

export function ProductCard({ product }: { product: Product }) {
  return (
    <article className="flex gap-3 rounded-xl border p-3">
      <Image src={product.image} alt="" width={96} height={96} className="rounded-lg" />
      <div className="ml-4 flex-1">
        <h3 className="text-sm font-medium">
          <Link href={`/products/${product.slug}`}>{product.name}</Link>
        </h3>
        <PriceTag cents={product.price} />
      </div>
    </article>
  );
}
