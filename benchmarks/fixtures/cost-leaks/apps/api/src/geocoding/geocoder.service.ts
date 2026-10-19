import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { CreditsService } from '../billing/credits.service';
import { geocoderLookups } from '../metrics/metrics';
import { SpendGuard } from '../spend/spend-guard';

export interface GeoPoint {
  lat: number;
  lng: number;
  precision: 'rooftop' | 'street' | 'postcode';
}

/** Geocodes recipient addresses for route planning (MapGrid, billed per lookup). */
@Injectable()
export class GeocoderService {
  constructor(
    private readonly config: AppConfig,
    private readonly credits: CreditsService,
    private readonly guard: SpendGuard,
  ) {}

  async geocode(tenantId: string, address: string): Promise<GeoPoint> {
    // The merchant's plan includes N lookups a month; overage is invoiced to the merchant.
    await this.credits.debit(tenantId, 'geocode', 1);
    // Org-wide monthly cap across all merchants (GEOCODER_MONTHLY_CAP), checked before the call.
    await this.guard.reserve('geocoder');
    const url = `${this.config.geocoderApiUrl}/v2/geocode?q=${encodeURIComponent(address)}`;
    const res = await fetch(url, {
      headers: { authorization: `Bearer ${this.config.geocoderApiKey}` },
      signal: AbortSignal.timeout(5_000),
    });
    geocoderLookups.inc({ tenant: tenantId, outcome: res.ok ? 'ok' : String(res.status) });
    if (!res.ok) {
      throw new Error(`geocoder ${res.status}`);
    }
    const body = (await res.json()) as { results: GeoPoint[] };
    return body.results[0];
  }
}
