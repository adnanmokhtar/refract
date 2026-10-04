import { createContext, useContext } from 'react';

export interface CartLine {
  productId: string;
  storeId: string;
  title: string;
  priceCents: number;
  quantity: number;
}

export interface CartContextValue {
  cart: CartLine[];
  addItem: (line: CartLine) => void;
  removeItem: (productId: string) => void;
  clear: () => void;
}

export const CartContext = createContext<CartContextValue>({
  cart: [],
  addItem: () => undefined,
  removeItem: () => undefined,
  clear: () => undefined,
});

export const useCart = () => useContext(CartContext);
