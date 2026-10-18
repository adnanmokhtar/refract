import { useQuery } from '@tanstack/react-query';
import { fetchReviews } from './reviews-api';

interface ReviewListProps {
  sku: string;
}

export function ReviewList({ sku }: ReviewListProps) {
  const { data } = useQuery({ queryKey: ['reviews', sku], queryFn: () => fetchReviews(sku) });
  return (
    <ul>
      {data?.map((r) => (
        <li key={r.id}>
          <time dateTime={r.createdAt}>{r.day}</time> {r.body}
        </li>
      ))}
    </ul>
  );
}
