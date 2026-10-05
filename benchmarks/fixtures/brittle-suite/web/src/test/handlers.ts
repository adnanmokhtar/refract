import { http, HttpResponse } from 'msw';

// Hand-written responses for the component tests.
export const handlers = [
  http.get('/api/invoices/:id', ({ params }) =>
    HttpResponse.json({
      id: params.id,
      number: 'INV-2026-0042',
      total: '12.00',
      currency: 'EUR',
      lines: [
        { description: 'Stoneware mug', quantity: 2, unitCents: 450 },
        { description: 'Return label', quantity: 1, unitCents: 300 },
      ],
    }),
  ),
  http.get('/api/returns/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, status: 'approved', refundCents: 1_200, dueBy: '2026-03-29T00:30:00Z' }),
  ),
];
