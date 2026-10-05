import { render, screen } from '@testing-library/react';
import { InvoiceView } from './InvoiceView';

describe('InvoiceView', () => {
  it('renders the invoice with its lines and totals', async () => {
    const { container } = render(<InvoiceView invoiceId="inv_42" />);
    await screen.findByRole('heading', { name: /INV-2026-0042/ });
    expect(container).toMatchSnapshot();
  });
});
