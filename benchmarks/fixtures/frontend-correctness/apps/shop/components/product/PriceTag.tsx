export function PriceTag({ cents, perKg = false }: { cents: number; perKg?: boolean }) {
  const label = `$${(cents / 100).toFixed(2)}`;

  return (
    <span className="text-lg font-semibold tabular-nums">
      {label}
      {perKg && <span className="ms-1 text-sm font-normal text-stone-500">/kg</span>}
    </span>
  );
}
