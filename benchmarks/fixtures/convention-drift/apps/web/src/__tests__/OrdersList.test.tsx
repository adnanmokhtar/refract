import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { OrderCard } from '../features/orders/components/OrderCard';

describe('orders list', () => {
  it('shows the order reference', () => {
    render(
      <OrderCard order={{ id: '1', reference: 'A-1001', status: 'paid', totalMinor: 1250, currency: 'EUR', createdAt: '2026-10-01' }} />,
    );
    expect(screen.getByText('A-1001')).toBeTruthy();
  });
});
