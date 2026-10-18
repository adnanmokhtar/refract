import ky from 'ky';
import { HTTPError } from 'ky';
import dayjs from 'dayjs';

const reviews = ky.create({ prefixUrl: '/api/v2/reviews' });

export type Review = { id: string; rating: number; body: string; createdAt: string };

export async function fetchReviews(sku: string): Promise<Array<Review & { day: string }>> {
  try {
    const list = await reviews.get(sku).json<Review[]>();
    return list.map((r) => ({ ...r, day: dayjs(r.createdAt).format('YYYY-MM-DD') }));
  } catch (error) {
    if (error instanceof HTTPError && error.response.status === 404) return [];
    throw error;
  }
}
