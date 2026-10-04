import { Link } from 'react-router';
import { useCart } from '../context/CartContext';

export interface CardProduct {
  id: string;
  storeSlug: string;
  slug: string;
  title: string;
  price: number;
  currency: string;
  imageUrl: string;
}

export function ProductCard({ product }: { product: CardProduct }) {
  const { cart, addItem } = useCart();
  const inCart = cart.some((l) => l.productId === product.id);
  return (
    <article className="product-card">
      <Link to={`/s/${product.storeSlug}/p/${product.slug}`}>
        <img src={product.imageUrl} alt="" width={220} height={220} loading="lazy" decoding="async" />
        <h3>{product.title}</h3>
      </Link>
      <p>
        {product.price.toFixed(2)} {product.currency}
      </p>
      <button
        disabled={inCart}
        onClick={() => addItem({ productId: product.id, storeId: product.storeSlug, title: product.title, priceCents: Math.round(product.price * 100), quantity: 1 })}
      >
        {inCart ? 'In cart' : 'Add to cart'}
      </button>
    </article>
  );
}
