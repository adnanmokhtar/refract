import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { OrderStatusBadge } from './OrderStatusBadge';

describe('OrderStatusBadge', () => {
  it('renders the translated status', () => {
    render(<OrderStatusBadge status="paid" />);
    expect(screen.getByText('Paid')).toBeTruthy();
  });

  it('marks a failed order in the danger colour', () => {
    render(<OrderStatusBadge status="failed" />);
    expect(screen.getByText('Failed').style.color).toBe('rgb(217, 45, 32)');
  });

  it('matches the snapshot', () => {
    const { container } = render(<OrderStatusBadge status="failed" />);
    expect(container.firstChild).toMatchSnapshot();
  });
});
