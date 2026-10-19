export function toCsvRow(values: unknown[]): string {
  return values
    .map((v) => (v === null || v === undefined ? '' : String(v)))
    .map((v) => (/[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v))
    .join(',');
}
