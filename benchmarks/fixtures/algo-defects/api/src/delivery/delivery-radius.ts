export interface LatLng {
  lat: number;
  lng: number;
}

/** Checkout calls this before it offers delivery; outside the radius the shopper only sees click-and-collect. */
export function isWithinDeliveryRadius(store: LatLng, address: LatLng, radiusKm: number): boolean {
  const { lat: lat1, lng: lng1 } = store;
  const { lat: lat2, lng: lng2 } = address;
  const km = Math.sqrt((lat2 - lat1) ** 2 + (lng2 - lng1) ** 2) * 111;
  return km <= radiusKm;
}

export function deliveryFeeBand(km: number, bands: { upToKm: number; feeMinor: number }[]): number | null {
  const band = bands.find((b) => km <= b.upToKm);
  return band ? band.feeMinor : null;
}
