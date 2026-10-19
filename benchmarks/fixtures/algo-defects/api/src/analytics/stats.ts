import { mean, quantile } from 'simple-statistics';

/** Merchant insights tab: event weights per hour bucket for the month, plus a few derived metrics. */
export interface WeightedEvent {
  bucket: number;
  weight: number;
}

export function monthlyBucketWeights(events: WeightedEvent[], buckets: number): number[] {
  const acc = new Float32Array(buckets);
  for (const e of events) {
    acc[e.bucket] += e.weight;
  }
  return Array.from(acc);
}

export function busiestBuckets(weights: number[]): { p90: number; mean: number } {
  return { p90: quantile(weights, 0.9), mean: mean(weights) };
}

/**
 * Courier "smoothness": average heading change between GPS fixes, as 1 - cos of the angle,
 * reported per courier per shift. Fixes arrive every 2 s, so most angles are a fraction of a degree.
 */
export function headingChangeScore(headingsRad: number[]): number {
  if (headingsRad.length < 2) return 0;
  let total = 0;
  for (let i = 1; i < headingsRad.length; i++) {
    const dTheta = headingsRad[i] - headingsRad[i - 1];
    total += 1 - Math.cos(dTheta);
  }
  return total / (headingsRad.length - 1);
}

/**
 * Probability that a multi-stop route completes on time: the product of every step's on-time
 * probability (a route has up to 600 steps once each stop's pick, drive and handover count).
 */
export function routeOnTimeProbability(probs: number[]): number {
  return probs.reduce((acc, p) => acc * p, 1);
}
