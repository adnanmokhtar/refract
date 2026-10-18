import { useMutation, useQuery } from '@tanstack/react-query';
import { apiClient } from '@acme/http';

type Quote = { totalMinor: number; currency: string };

export function usePayment() {
  const quote = useQuery({ queryKey: ['checkout', 'quote'], queryFn: () => apiClient.get('checkout/quote').json<Quote>() });
  const pay = useMutation({ mutationFn: (body: { coupon: string }) => apiClient.post('checkout/pay', { json: body }).json() });
  return { ...pay, totalMinor: quote.data?.totalMinor ?? 0, currency: quote.data?.currency ?? 'EUR' };
}
