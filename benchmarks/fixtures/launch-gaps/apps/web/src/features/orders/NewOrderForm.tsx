import { useState } from 'react';
import { Button } from '../../components/Button';
import { usePlaceOrder } from './use-place-order';

export function NewOrderForm() {
  const place = usePlaceOrder();
  const [sku, setSku] = useState('');
  const [qty, setQty] = useState(1);
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        place.mutate({ lines: [{ sku, qty }] });
      }}
    >
      <input value={sku} onChange={(e) => setSku(e.target.value)} aria-label="SKU" />
      <input type="number" min={1} value={qty} onChange={(e) => setQty(Number(e.target.value))} aria-label="Quantity" />
      <Button type="submit" disabled={place.isPending}>
        Add order
      </Button>
    </form>
  );
}
