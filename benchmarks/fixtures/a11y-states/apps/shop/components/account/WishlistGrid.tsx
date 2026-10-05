'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useWishlist } from '@/lib/queries';
import { api } from '@/lib/api';
import { ProductCard } from '@/components/product/ProductCard';
import { ErrorState } from '@/components/ui/ErrorState';

export function WishlistGrid() {
  const qc = useQueryClient();
  const { data, isPending, isError, refetch } = useWishlist();
  const quickAdd = useMutation({
    mutationFn: (productId: string) => api.post('/me/cart/lines', { productId, qty: 1 }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['me', 'cart'] }),
  });

  if (isPending) {
    return (
      <div aria-busy="true" className="grid grid-cols-2 gap-4 sm:grid-cols-3">
        {Array.from({ length: 6 }, (_, n) => (
          <div key={n} className="aspect-[4/5] animate-pulse rounded-card bg-muted" />
        ))}
      </div>
    );
  }
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  return (
    <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
      {data.items.map((product) => (
        <ProductCard key={product.id} product={product} onQuickAdd={(id) => quickAdd.mutate(id)} />
      ))}
    </div>
  );
}
