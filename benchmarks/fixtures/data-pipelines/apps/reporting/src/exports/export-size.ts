/** Exports above the ceiling are refused with a message, never cut. */
export const EXPORT_MAX_ROWS = 200_000;

export class ExportTooLargeError extends Error {
  constructor(kind: string, rows: number) {
    super(`Export "${kind}" has ${rows} rows; the limit is ${EXPORT_MAX_ROWS}. Narrow the filter and try again.`);
  }
}

export async function collectPages<T>(kind: string, read: (page: number) => Promise<{ items: T[]; last: boolean }>): Promise<T[]> {
  const out: T[] = [];
  for (let page = 1; ; page += 1) {
    const { items, last } = await read(page);
    out.push(...items);
    if (out.length > EXPORT_MAX_ROWS) throw new ExportTooLargeError(kind, out.length);
    if (last) return out;
  }
}
