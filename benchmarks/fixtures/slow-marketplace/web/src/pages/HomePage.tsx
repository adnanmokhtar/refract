import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { ProductCard } from '../components/ProductCard';
import { api } from '../lib/api';

interface HomeFeed {
  featured: { id: string; slug: string; storeSlug: string; title: string; price: number; currency: string; imageUrl: string }[];
  categories: { slug: string; products: number }[];
  latestReviews: { id: string; productTitle: string; rating: number; body: string; photoUrl?: string }[];
}

// The campaign hero is swapped by marketing through the CDN; the URL stays the same.
const HERO = {
  imageUrl: 'https://media.stallwise.example/campaign/hero-1600.avif',
  alt: 'Autumn market — 400 independent stores, one checkout',
};

export default function HomePage() {
  const { data: feed } = useQuery({ queryKey: ['home'], queryFn: () => api<HomeFeed>('/api/home') });

  return (
    <main>
      <section className="hero">
        <img className="hero__image" src={HERO.imageUrl} alt={HERO.alt} width={1600} height={640} loading="lazy" />
        <div className="hero__copy">
          <h1>Independent stores, one checkout</h1>
          <Link to="/c/new-in">Shop new arrivals</Link>
        </div>
      </section>

      <section aria-label="Featured">
        <h2>Featured this week</h2>
        <div className="grid">
          {feed?.featured.map((p) => <ProductCard key={p.id} product={p} />)}
        </div>
      </section>

      <nav aria-label="Categories" className="category-strip">
        {feed?.categories.map((c) => (
          <Link key={c.slug} to={`/c/${c.slug}`}>
            {c.slug} <span>({c.products})</span>
          </Link>
        ))}
      </nav>

      <section aria-label="Latest reviews" className="latest-reviews">
        <h2>What buyers are saying</h2>
        {feed?.latestReviews.map((r) => (
          <article key={r.id} className="review-card">
            {r.photoUrl && (
              <img className="review-card__photo" src={r.photoUrl} alt="" width={120} height={120} loading="lazy" decoding="async" />
            )}
            <p className="review-card__rating">{'★'.repeat(r.rating)}</p>
            <p>{r.body}</p>
            <small>{r.productTitle}</small>
          </article>
        ))}
      </section>
    </main>
  );
}
