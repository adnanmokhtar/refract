import { FUZZ_CONFIG } from './fuzz.config';

export type Rng = () => number;

/** Mulberry32: small, seedable, reproducible across runs. */
export function mulberry32(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export interface Property<T> {
  name: string;
  generate: (rng: Rng) => T;
  shrink: (value: T) => T[];
  check: (value: T) => boolean;
}

export function fuzz<T>(prop: Property<T>, corpus: T[] = []): void {
  const rng = mulberry32(FUZZ_CONFIG.seed);
  const inputs = [...corpus, ...Array.from({ length: FUZZ_CONFIG.runs }, () => prop.generate(rng))];
  for (const input of inputs) {
    if (!prop.check(input)) {
      let smallest = input;
      for (let progress = true; progress; ) {
        progress = false;
        for (const candidate of prop.shrink(smallest)) {
          if (!prop.check(candidate)) {
            smallest = candidate;
            progress = true;
            break;
          }
        }
      }
      throw new Error(`${prop.name} failed for ${JSON.stringify(smallest)}`);
    }
  }
}
