export type DraftOrder = {
  storeId: string;
  slotId: string;
  addressId: string;
  lines: { productId: string; quantity: number }[];
  substitutions: 'allow' | 'ask' | 'never';
};
