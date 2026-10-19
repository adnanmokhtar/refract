import { useMemo, useState } from 'react';
import { AttributeInput, buildVariantMatrix } from './variant-matrix';

export function VariantMatrixPanel({ initial }: { initial: AttributeInput[] }) {
  const [attrs, setAttrs] = useState<AttributeInput[]>(initial);
  const matrix = useMemo(() => buildVariantMatrix(attrs), [attrs]);

  const addValue = (name: string, value: string) =>
    setAttrs((prev) => prev.map((a) => (a.name === name ? { ...a, values: [...a.values, value] } : a)));

  return (
    <section>
      {attrs.map((a) => (
        <fieldset key={a.name}>
          <legend>{a.name}</legend>
          <input
            placeholder="Add a value and press Enter"
            onKeyDown={(e) => {
              if (e.key === 'Enter' && e.currentTarget.value.trim()) {
                addValue(a.name, e.currentTarget.value.trim());
                e.currentTarget.value = '';
              }
            }}
          />
        </fieldset>
      ))}
      {matrix.error ? <p role="alert">{matrix.error}</p> : <p>{matrix.rows.length} variants</p>}
    </section>
  );
}
