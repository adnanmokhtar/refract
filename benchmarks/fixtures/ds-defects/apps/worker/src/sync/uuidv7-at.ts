/** The smallest UUIDv7 whose timestamp is `ms`: a lower bound for every id minted at or after that instant. */
export function uuidv7At(ms: number): string {
  const hex = ms.toString(16).padStart(12, '0');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-7000-8000-000000000000`;
}
