import Link from 'next/link';
import type { Product } from '@/lib/api';

export function Recommended({ products }: { products: Product[] }) {
  return (
    <section className="mt-16" aria-labelledby="recommended-heading">
      <h2 id="recommended-heading" className="text-lg font-semibold">Recommended for you</h2>
      <ul className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        {products.map((p) => (
          <li key={p.id}>
            <Link href={`/products/${p.slug}`}>{p.name}</Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
