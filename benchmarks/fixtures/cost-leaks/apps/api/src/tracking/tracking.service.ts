import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import type { CarrierScan } from './carrier.client';

export interface PublicShipment {
  id: string;
  tenantId: string;
  trackingNumber: string;
  status: string;
  eta: string | null;
}

@Injectable()
export class TrackingService {
  constructor(private readonly em: EntityManager) {}

  async findPublic(code: string): Promise<PublicShipment | null> {
    const rows = await this.em.getConnection().execute<PublicShipment[]>(
      'select id, tenant_id as "tenantId", tracking_number as "trackingNumber", status, eta from shipments where public_code = ?',
      [code],
    );
    return rows[0] ?? null;
  }

  async findInTransit(limit: number): Promise<{ trackingNumber: string }[]> {
    return this.em.getConnection().execute(
      `select tracking_number as "trackingNumber" from shipments where status in ('label_created', 'in_transit', 'out_for_delivery') order by updated_at limit ?`,
      [limit],
    );
  }

  async applyScans(scans: CarrierScan[]): Promise<void> {
    for (const scan of scans) {
      await this.em.getConnection().execute(
        'update shipments set status = ?, updated_at = now() where tracking_number = ? and status <> ?',
        [scan.code, scan.trackingNumber, scan.code],
      );
    }
  }

  assistantPrompt(shipment: PublicShipment): string {
    return [
      'You answer questions about one parcel. Use only the facts below; say when you do not know.',
      `Status: ${shipment.status}. Estimated delivery: ${shipment.eta ?? 'unknown'}.`,
    ].join('\n');
  }
}
