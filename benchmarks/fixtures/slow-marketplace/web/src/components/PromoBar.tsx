const SALE_ENDS = Date.parse('2025-10-31T23:00:00Z');

export function PromoBar({ now }: { now: number }) {
  const left = Math.max(0, SALE_ENDS - now);
  const h = Math.floor(left / 3_600_000);
  const m = Math.floor((left % 3_600_000) / 60_000);
  const s = Math.floor((left % 60_000) / 1_000);
  return <div className="promo-bar">Autumn market ends in {h}h {m}m {s}s</div>;
}
