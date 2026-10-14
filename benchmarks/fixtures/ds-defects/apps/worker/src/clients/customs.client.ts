import { Injectable } from '@nestjs/common';
import { HttpClient } from './http-client';

/**
 * Files export declarations with the customs broker. The broker deduplicates on `reference` (the shipment id) for
 * 72 h and answers a repeated submission with the original MRN (broker API guide, "Idempotent submission").
 */
@Injectable()
export class CustomsClient {
  constructor(private readonly http: HttpClient) {}

  async fileDeclaration(shipmentId: string, declaration: Record<string, unknown>): Promise<{ mrn: string }> {
    return this.http.call({
      method: 'POST',
      url: `${process.env.CUSTOMS_BROKER_URL}/declarations`,
      body: { reference: shipmentId, ...declaration },
      requestTimeout: 10_000,
      retry: { attempts: 3, backoffMs: 2_000 },
    });
  }
}
