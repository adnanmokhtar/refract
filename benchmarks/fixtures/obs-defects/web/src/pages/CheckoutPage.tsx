import { useState } from 'react';

export default function CheckoutPage({ cartId, userId }: { cartId: string; userId: string }) {
  const [status, setStatus] = useState<'idle' | 'placing' | 'done' | 'failed'>('idle');

  async function placeOrder() {
    setStatus('placing');
    const res = await fetch('/api/checkout', { method: 'POST', body: JSON.stringify({ cartId, userId }), headers: { 'content-type': 'application/json' } });
    setStatus(res.ok ? 'done' : 'failed');
  }

  return (
    <main>
      <h1>Checkout</h1>
      <button type="button" onClick={placeOrder} disabled={status === 'placing'}>Place order</button>
      {status === 'failed' && <p role="alert">We could not place your order. Please try again.</p>}
    </main>
  );
}
