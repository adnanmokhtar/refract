// Storefront search runs on a hosted search cluster. The seller dashboard pushes a listing
// straight to the index on save so it shows up in search without waiting for the nightly
// reindex job.

const SEARCH_HOST = import.meta.env.VITE_SEARCH_HOST;
const SEARCH_ADMIN_KEY = import.meta.env.VITE_SEARCH_ADMIN_KEY;

export interface IndexedProduct {
  id: string;
  title: string;
  priceCents: number;
  sellerId: string;
  thumbnailUrl?: string | null;
}

export async function pushToSearchIndex(product: IndexedProduct): Promise<void> {
  const res = await fetch(`${SEARCH_HOST}/indexes/products/documents`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${SEARCH_ADMIN_KEY}`,
    },
    body: JSON.stringify([product]),
  });
  if (!res.ok) throw new Error(`search index update failed (${res.status})`);
}
