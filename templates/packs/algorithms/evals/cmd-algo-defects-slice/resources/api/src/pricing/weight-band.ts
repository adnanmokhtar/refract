import _ from 'lodash';

export interface WeightBand {
  id: string;
  maxKg: number;
  feeMinor: number;
}

/** Bands as the settings service caches them: keyed by band id, in the order the rows were read. */
export type BandsById = Record<string, WeightBand>;

export function indexBands(rows: WeightBand[]): BandsById {
  return Object.fromEntries(rows.map((r) => [r.id, r]));
}

/** The fee band for a parcel: the first band whose maxKg is at or above the weight. */
export function bandFor(bandsById: BandsById, weightKg: number): WeightBand | undefined {
  const bands = Object.values(bandsById);
  const i = _.sortedIndex(bands.map((b) => b.maxKg), weightKg);
  return bands[i];
}
