import { useQuery } from '@tanstack/react-query';
import { ChangeEvent, useDeferredValue, useMemo, useState } from 'react';
import { useParams } from 'react-router';
import { ProductCard } from '../components/ProductCard';
import { api } from '../lib/api';

interface Product {
  id: string;
  storeSlug: string;
  slug: string;
  title: string;
  price: number;
  currency: string;
  imageUrl: string;
  updatedAt: string;
}

type Sort = 'relevance' | 'price-asc' | 'price-desc' | 'newest';
type Facets = { maxPrice?: number; store?: string };

const PAGE = 96;

// Rank by how early the query appears in the title, then by the chosen sort.
function sortAndFilter(products: Product[], query: string, sort: Sort): Product[] {
  const q = query.trim().toLowerCase();
  const matches = q ? products.filter((p) => p.title.toLowerCase().includes(q)) : [...products];
  return matches.sort((a, b) => {
    if (q) {
      const rank = a.title.toLowerCase().indexOf(q) - b.title.toLowerCase().indexOf(q);
      if (rank !== 0) return rank;
    }
    if (sort === 'price-asc') return a.price - b.price;
    if (sort === 'price-desc') return b.price - a.price;
    if (sort === 'newest') return b.updatedAt.localeCompare(a.updatedAt);
    return a.title.localeCompare(b.title);
  });
}

function applyFacets(products: Product[], facets: Facets): Product[] {
  return products.filter((p) => (facets.maxPrice === undefined || p.price <= facets.maxPrice) && (!facets.store || p.storeSlug === facets.store));
}

// Category page. The whole category comes from the edge snapshot in one response (the big
// categories have ~20 000 products) so filtering and sorting feel instant without a round trip.
export default function CatalogPage() {
  const { category = 'new-in' } = useParams();
  const { data: products = [] } = useQuery({
    queryKey: ['catalog', category],
    queryFn: () => api<Product[]>(`/api/catalog/snapshot/${encodeURIComponent(category)}`),
  });

  const [query, setQuery] = useState('');
  const [sort, setSort] = useState<Sort>('relevance');
  const [visible, setVisible] = useState<Product[] | null>(null);
  const [facets, setFacets] = useState<Facets>({});
  const [shown, setShown] = useState(PAGE);

  const deferredFacet = useDeferredValue(facets);
  const faceted = useMemo(() => applyFacets(visible ?? products, deferredFacet), [visible, products, deferredFacet]);

  const onSortChange = (e: ChangeEvent<HTMLSelectElement>) => {
    const next = e.target.value as Sort;
    setSort(next);
    setVisible(sortAndFilter(products, query, next));
  };

  const onMaxPrice = (e: ChangeEvent<HTMLInputElement>) => {
    setFacets((f) => ({ ...f, maxPrice: e.target.value ? Number(e.target.value) : undefined }));
  };

  // Results update as the buyer types.
  const onSearchInput = (e: ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setQuery(value);
    setVisible(sortAndFilter(products, value, sort));
    setShown(PAGE);
  };

  return (
    <main>
      <header className="catalog-toolbar">
        <input type="search" value={query} onChange={onSearchInput} placeholder={`Search ${category}`} />
        <select value={sort} onChange={onSortChange}>
          <option value="relevance">Best match</option>
          <option value="price-asc">Price, low to high</option>
          <option value="price-desc">Price, high to low</option>
          <option value="newest">Newest</option>
        </select>
        <input type="range" min={0} max={500} onChange={onMaxPrice} aria-label="Maximum price" />
      </header>
      <div className="grid">
        {faceted.slice(0, shown).map((p) => (
          <ProductCard key={p.id} product={p} />
        ))}
      </div>
      {faceted.length > shown && <button onClick={() => setShown((n) => n + PAGE)}>Show more</button>}
    </main>
  );
}
