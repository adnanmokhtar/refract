import { env } from '../env.js';

export interface GeoPoint {
  lat: number;
  lng: number;
}

/** Geocodes a merchant address for the map pin. */
export function geocode(address: string): Promise<GeoPoint> {
  return fetch(`${env.GEO_BASE_URL}/geocode?q=${encodeURIComponent(address)}`, { signal: AbortSignal.timeout(3000) })
    .then((r) => r.json())
    .then((body: { results: GeoPoint[] }) => body.results[0]);
}
