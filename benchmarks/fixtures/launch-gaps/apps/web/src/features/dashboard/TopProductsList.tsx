import type { TopProduct } from './use-top-products';

export function TopProductsList({ products }: { products: TopProduct[] }) {
  return (
    <ol>
      {products.map((p) => (
        <li key={p.sku}>
          {p.name} · {p.unitsSold} sold
        </li>
      ))}
    </ol>
  );
}
