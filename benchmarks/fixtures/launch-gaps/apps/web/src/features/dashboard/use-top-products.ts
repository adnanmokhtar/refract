export interface TopProduct {
  sku: string;
  name: string;
  unitsSold: number;
  revenueCents: number;
}

/** The dashboard's "top products this week" list. */
export function useTopProducts(): TopProduct[] {
  // TODO: read GET /api/insights/top-products once the endpoint exists
  return [
    { sku: 'SW-1001', name: 'Oat milk 1L', unitsSold: 412, revenueCents: 205588 },
    { sku: 'SW-1044', name: 'Sourdough loaf', unitsSold: 268, revenueCents: 160532 },
    { sku: 'SW-2010', name: 'Cold brew 330ml', unitsSold: 190, revenueCents: 94810 },
  ];
}
