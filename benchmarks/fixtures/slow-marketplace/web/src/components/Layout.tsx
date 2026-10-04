import { ReactNode } from 'react';
import { Link } from 'react-router';
import { useCart } from '../context/CartContext';

export function Layout({ children }: { children: ReactNode }) {
  const { cart } = useCart();
  const count = cart.reduce((n, l) => n + l.quantity, 0);
  return (
    <>
      <header className="site-header">
        <Link to="/">stallwise</Link>
        <Link to="/cart">Cart ({count})</Link>
      </header>
      {children}
    </>
  );
}
