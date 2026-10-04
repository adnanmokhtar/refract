import DOMPurify from 'dompurify';
import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { SellerCard, SellerSummary } from '../components/SellerCard';
import { api } from '../lib/api';

interface Review {
  id: string;
  rating: number;
  bodyHtml: string;
  createdAt: string;
}

interface Product {
  id: string;
  title: string;
  descriptionHtml: string;
  priceCents: number;
  currency: string;
  thumbnailUrl: string | null;
  seller: SellerSummary;
  reviews: Review[];
}

const money = (cents: number, currency: string) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(cents / 100);

export function ProductPage() {
  const { id } = useParams();
  const [product, setProduct] = useState<Product | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Product>(`/products/${id}`).then(setProduct, (e: Error) => setError(e.message));
  }, [id]);

  if (error) return <p role="alert">{error}</p>;
  if (!product) return <p aria-busy="true">Loading…</p>;

  return (
    <main className="product">
      {product.thumbnailUrl && <img className="product__image" src={product.thumbnailUrl} alt={product.title} />}
      <h1>{product.title}</h1>
      <p className="product__price">{money(product.priceCents, product.currency)}</p>

      {/* Sellers write descriptions in the rich-text editor, so this is HTML. */}
      <div className="product__description" dangerouslySetInnerHTML={{ __html: product.descriptionHtml }} />

      <SellerCard seller={product.seller} />

      <details className="product__shipping">
        <summary>Shipping &amp; returns</summary>
        <p>Ships from the seller within 3 business days. Returns accepted within 30 days.</p>
      </details>

      <section className="reviews" aria-label="Reviews">
        <h2>Reviews</h2>
        {product.reviews.length === 0 && <p>No reviews yet.</p>}
        {product.reviews.map((review) => (
          <article key={review.id} className="review">
            <span className="review__rating" aria-label={`${review.rating} out of 5`}>
              {'★'.repeat(review.rating)}
            </span>
            <div className="review__body" dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(review.bodyHtml) }} />
            <time dateTime={review.createdAt}>{new Date(review.createdAt).toLocaleDateString()}</time>
          </article>
        ))}
      </section>
    </main>
  );
}
