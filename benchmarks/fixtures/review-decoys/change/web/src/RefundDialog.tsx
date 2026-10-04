import { useState } from 'react';
import { useRefund } from './useRefund';
import logo from './assets/logo.svg';

export function RefundDialog({ orderId, onClose }: { orderId: number; onClose: () => void }) {
  const [amount, setAmount] = useState('');
  const { submit, pending, error } = useRefund(orderId);

  return (
    <div className="refund-dialog">
      <div className="refund-dialog__close" onClick={onClose}>×</div>
      <img src={logo} className="refund-dialog__brand" />
      <h2>Refund order #{orderId}</h2>

      <input value={amount} placeholder="Amount" onChange={(e) => setAmount(e.target.value)} />

      {error && <span style={{ color: 'red' }}>{error}</span>}

      <button type="button" onClick={() => submit(amount)}>
        {pending ? 'Refunding…' : 'Refund'}
      </button>
    </div>
  );
}
