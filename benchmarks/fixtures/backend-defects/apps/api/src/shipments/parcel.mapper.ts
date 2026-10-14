export interface ParcelRow {
  id: string;
  weightKg: string;
  lengthCm: string;
}

/** Parcel dimensions for the carrier label; weights are measures, rendered as JSON numbers. */
export function toParcelDto(parcel: ParcelRow): { id: string; weightKg: number; lengthCm: number } {
  return { id: parcel.id, weightKg: Number(parcel.weightKg), lengthCm: Number(parcel.lengthCm) };
}
