import { z } from 'zod';

// V1 parity: Laravel never rejects a list query. The paginator falls back to page 1 for anything that is not an
// integer ≥ 1, and controllers clamp `per_page` with `min((int) $input, 100)`; 0 or garbage gives Eloquent's 15.
const toPage = (n: number) => (Number.isInteger(n) && n >= 1 ? n : 1);
const toPerPage = (n: number) => (Math.trunc(n) >= 1 ? Math.min(Math.trunc(n), 100) : 15);

// Wire keys stay snake_case: V1 clients (the mobile app, the partner integrations) read them.
export const PageQuery = z.object({
  page: z.coerce.number().default(1).catch(1).transform(toPage).pipe(z.number().int()),
  per_page: z.coerce.number().default(20).catch(15).transform(toPerPage).pipe(z.number().int()),
});

export type PageQueryT = z.infer<typeof PageQuery>;

export const Money = z.string().regex(/^-?\d+\.\d{2}$/);
