import { Suspense } from 'react';
import { getCategory } from '@/lib/server/catalog';
import { ProductCard } from '@/components/product/ProductCard';
import { SortSelect } from '@/components/catalog/SortSelect';
import { Pagination } from '@/components/catalog/Pagination';

export default async function CategoryPage({ params }: { params: Promise<{ slug: string[] }> }) {
  const { slug } = await params;
  const category = await getCategory(slug);

  return (
    <section className="mt-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">{category?.title}</h1>
        <SortSelect />
      </div>
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        {(category?.products ?? []).map((p) => (
          <ProductCard key={p.id} product={p} />
        ))}
      </div>
      <Suspense fallback={null}>
        <Pagination pages={4} />
      </Suspense>
    </section>
  );
}
