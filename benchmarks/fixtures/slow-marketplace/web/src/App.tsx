import { useCallback, useEffect, useState } from 'react';
import { RouterProvider } from 'react-router';
import { PromoBar } from './components/PromoBar';
import { CartContext, CartLine } from './context/CartContext';
import { SessionProvider } from './context/SessionContext';
import { router } from './routes';

const CART_KEY = 'stallwise.cart.v2';

const loadCart = (): CartLine[] => {
  try {
    return JSON.parse(localStorage.getItem(CART_KEY) ?? '[]') as CartLine[];
  } catch {
    return [];
  }
};

export default function App() {
  const [cart, setCart] = useState<CartLine[]>(loadCart);
  const [now, setNow] = useState(() => Date.now());

  // The flash-sale countdown in the promo bar ticks every second.
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1_000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    localStorage.setItem(CART_KEY, JSON.stringify(cart));
  }, [cart]);

  const addItem = useCallback((line: CartLine) => {
    setCart((current) => {
      const existing = current.find((l) => l.productId === line.productId);
      if (!existing) return [...current, line];
      return current.map((l) => (l.productId === line.productId ? { ...l, quantity: l.quantity + line.quantity } : l));
    });
  }, []);

  const removeItem = useCallback((productId: string) => {
    setCart((current) => current.filter((l) => l.productId !== productId));
  }, []);

  const clear = useCallback(() => setCart([]), []);

  return (
    <SessionProvider>
      <CartContext.Provider value={{ cart, addItem, removeItem, clear }}>
        <PromoBar now={now} />
        <RouterProvider router={router} />
      </CartContext.Provider>
    </SessionProvider>
  );
}
