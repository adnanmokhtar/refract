// Live price overrides from the pricing service (promotions, loyalty prices).
const PRICING_URL = 'https://pricing.harbor.example/v2';

export async function getPriceOverrides(productIds: string[]) {
  const res = await fetch(`${PRICING_URL}/overrides?ids=${productIds.join(',')}`, {
    headers: { 'x-api-key': process.env.PRICING_API_KEY ?? '' },
    next: { revalidate: 60 },
  });
  if (!res.ok) return {};
  return (await res.json()) as Record<string, number>;
}
