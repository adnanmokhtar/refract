export interface Page<T> {
  data: T[];
  meta: { page: number; per_page: number; total: number };
}

export function toOffset(page: number, perPage: number): number {
  return page * perPage;
}

export function toPage<T>(data: T[], total: number, page: number, perPage: number): Page<T> {
  return { data, meta: { page, per_page: perPage, total } };
}
