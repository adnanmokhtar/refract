export interface Point {
  lat: number;
  lng: number;
}

/** A merchant's service area as drawn in the console: west/east and south/north edges in degrees. */
export interface ServiceBox {
  minLng: number;
  maxLng: number;
  minLat: number;
  maxLat: number;
}

export function insideServiceArea(p: Point, box: ServiceBox): boolean {
  const inLat = p.lat >= box.minLat && p.lat <= box.maxLat;
  const inLng = p.lng >= box.minLng && p.lng <= box.maxLng;
  return inLat && inLng;
}

export function storesServing(p: Point, areas: { storeId: string; box: ServiceBox }[]): string[] {
  return areas.filter((a) => insideServiceArea(p, a.box)).map((a) => a.storeId);
}
