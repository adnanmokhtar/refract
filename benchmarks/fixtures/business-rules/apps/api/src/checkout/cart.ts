export interface CartLine {
  variantId: string;
  quantity: number;
  unitPriceMinor: number;
}

export interface Cart {
  storeId: string;
  currency: string;
  lines: CartLine[];
  /** Σ unit price × quantity, before any promotion or coupon. */
  subtotalMinor: number;
  couponCodes: string[];
  shippingMinor: number;
}
