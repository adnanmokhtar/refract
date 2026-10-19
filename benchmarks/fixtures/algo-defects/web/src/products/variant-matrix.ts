/** The server refuses a product with more variants than this (api: products module). */
export const MAX_VARIANTS = 500;

export interface AttributeInput {
  name: string;
  values: string[];
}

export type Combination = Record<string, string>;

/** Every combination of the attribute values the merchant typed, in the order the grid shows them. */
export function generateCombinations(attrs: AttributeInput[]): Combination[] {
  let combos: Combination[] = [{}];
  for (const attr of attrs) {
    const next: Combination[] = [];
    for (const c of combos) {
      for (const v of attr.values) next.push({ ...c, [attr.name]: v });
    }
    combos = next;
  }
  return combos;
}

export interface VariantMatrix {
  rows: Combination[];
  error?: string;
}

export function buildVariantMatrix(attrs: AttributeInput[]): VariantMatrix {
  const rows = generateCombinations(attrs);
  if (rows.length > MAX_VARIANTS) {
    return { rows: [], error: `A product can have at most ${MAX_VARIANTS} variants (this one would have ${rows.length}).` };
  }
  return { rows };
}
