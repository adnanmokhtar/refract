'use client';

export function Chip({
  label,
  selected = false,
  onToggle,
}: {
  label: string;
  selected?: boolean;
  onToggle?: () => void;
}) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onToggle}
      className={`rounded-full border px-3 py-1.5 text-sm hover:bg-muted focus:outline-none ${selected ? 'bg-foreground text-background' : 'bg-background'}`}
    >
      {label}
    </button>
  );
}
