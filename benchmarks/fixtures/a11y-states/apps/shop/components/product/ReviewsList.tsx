'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import styles from './rating.module.css';

type Review = { id: string; author: string; rating: number; body: string };

export function ReviewsList({ productId }: { productId: string }) {
  const t = useTranslations('product');
  const [reviews, setReviews] = useState<Review[] | null>(null);

  useEffect(() => {
    fetch(`/api/products/${productId}/reviews`, { signal: AbortSignal.timeout(8_000) })
      .then((r) => r.json())
      .then(setReviews)
      .catch(() => setReviews([]));
  }, [productId]);

  if (reviews === null) return <div aria-busy="true" className="mt-4 h-40 animate-pulse rounded-card bg-muted" />;
  if (reviews.length === 0) return <p className="mt-4 text-sm text-muted-foreground">{t('noReviews')}</p>;

  return (
    <ul className="mt-4 space-y-6">
      {reviews.map((review) => (
        <li key={review.id}>
          <p role="img" className={styles.stars} aria-label={`${review.rating} / 5`}>
            {[1, 2, 3, 4, 5].map((n) => (
              <span key={n} aria-hidden className={n <= review.rating ? styles.star : styles.starEmpty}>
                ★
              </span>
            ))}
          </p>
          <p className="mt-1 text-sm font-medium">{review.author}</p>
          <p className="mt-1 text-sm">{review.body}</p>
        </li>
      ))}
    </ul>
  );
}
