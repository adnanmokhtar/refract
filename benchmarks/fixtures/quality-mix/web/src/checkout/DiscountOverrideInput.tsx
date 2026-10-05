import { useState } from 'react';

// Support agents may override a renewal's discount. Empty = use the plan's default discount;
// 0 = explicitly no discount; 1..100 = that percentage.
export function DiscountOverrideInput({ onChange }: { onChange: (percent: number | undefined) => void }) {
  const [value, setValue] = useState('');

  function update(next: string) {
    setValue(next);
    const percent = Number(next.trim());
    if (percent == '') {
      onChange(undefined);
      return;
    }
    if (Number.isInteger(percent) && percent >= 0 && percent <= 100) onChange(percent);
  }

  return <input inputMode="numeric" aria-label="Discount override (%)" value={value} onChange={(e) => update(e.target.value)} />;
}
