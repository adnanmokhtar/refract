import { createContext, useContext, useState, type ReactNode } from 'react';

import type { CartLine } from './cart';

type Basket = {
  lines: CartLine[];
  add: (line: CartLine) => void;
  remove: (id: string) => void;
};

const BasketContext = createContext<Basket | null>(null);

// The app builds with the React Compiler (app.json experiments.reactCompiler), which memoizes the value below.
export function BasketProvider({ children }: { children: ReactNode }) {
  const [lines, setLines] = useState<CartLine[]>([]);
  const add = (line: CartLine) => setLines((current) => [...current, line]);
  const remove = (id: string) => setLines((current) => current.filter((l) => l.id !== id));

  return <BasketContext.Provider value={{ lines, add, remove }}>{children}</BasketContext.Provider>;
}

export function useBasket(): Basket {
  const basket = useContext(BasketContext);
  if (!basket) throw new Error('useBasket outside BasketProvider');
  return basket;
}
