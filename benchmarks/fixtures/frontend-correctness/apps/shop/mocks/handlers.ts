import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/me', () => HttpResponse.json({ id: 'c_1', name: 'Demo Customer', email: 'demo@harbor.example' })),
  http.get('/api/me/basket', () => HttpResponse.json({ lines: [] })),
];
