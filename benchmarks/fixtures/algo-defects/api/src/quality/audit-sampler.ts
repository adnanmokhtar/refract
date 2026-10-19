/**
 * Quality team: each shift, one packed order per picker is re-opened and inspected.
 * The inspector gets a position in the picker's packed list for the shift, inclusive of both ends.
 */
export interface ShiftRange {
  min: number;
  max: number;
}

export function inspectionPosition(range: ShiftRange): number {
  const { min, max } = range;
  if (max < min) {
    throw new RangeError('empty shift');
  }
  const pick = Math.floor(Math.random() * (max - min)) + min;
  return pick;
}

export function inspectionPlan(pickers: { pickerId: string; packed: number }[]): { pickerId: string; position: number }[] {
  return pickers
    .filter((p) => p.packed > 0)
    .map((p) => ({ pickerId: p.pickerId, position: inspectionPosition({ min: 1, max: p.packed }) }));
}
