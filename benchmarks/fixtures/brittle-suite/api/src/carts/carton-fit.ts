export interface Carton {
  name: 'small' | 'medium' | 'large';
  maxVolumeCm3: number;
}

export interface PackPlan {
  carton: Carton['name'];
  volumeCm3: number;
}

export class CartonOverflowError extends Error {}

export const CARTONS: Record<Carton['name'], Carton> = {
  small: { name: 'small', maxVolumeCm3: 6_000 },
  medium: { name: 'medium', maxVolumeCm3: 18_000 },
  large: { name: 'large', maxVolumeCm3: 48_000 },
};

// Picks the smallest return carton the items fit in.
export function planCarton(itemVolumesCm3: number[]): PackPlan {
  const volume = itemVolumesCm3.reduce((sum, v) => sum + v, 0);
  const carton = Object.values(CARTONS).find((c) => volume <= c.maxVolumeCm3);
  if (!carton) throw new CartonOverflowError(`${volume} cm3 exceeds the large carton`);
  return { carton: carton.name, volumeCm3: volume };
}

// Asserts a plan really fits its carton; used by the packing station before it prints a label.
export function fit(plan: PackPlan, carton: Carton): void {
  if (plan.volumeCm3 > carton.maxVolumeCm3) throw new CartonOverflowError(`${plan.volumeCm3} cm3 > ${carton.name}`);
}
