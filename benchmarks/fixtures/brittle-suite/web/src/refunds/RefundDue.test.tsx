import { render, screen } from '@testing-library/react';
import { RefundDue } from './RefundDue';

describe('RefundDue', () => {
  it('shows the due date of an approved refund', () => {
    render(<RefundDue dueBy="2026-03-29T00:30:00Z" />);
    expect(screen.getByText(/Refund due by/)).toHaveTextContent('Refund due by Mar 29, 2026');
  });

  it('shows nothing else in the banner', () => {
    const { container } = render(<RefundDue dueBy="2026-04-02T12:00:00Z" />);
    expect(container.querySelectorAll('p')).toHaveLength(1);
  });
});
