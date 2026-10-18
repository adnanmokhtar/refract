// V1 stores naive DATETIME values in Asia/Riyadh wall-clock time (config/app.php timezone).
// Riyadh has no DST, so the offset is a constant +03:00.
export function fromV1Local(value: string | null): string | null {
  return value ? new Date(`${value.replace(' ', 'T')}+03:00`).toISOString() : null;
}
