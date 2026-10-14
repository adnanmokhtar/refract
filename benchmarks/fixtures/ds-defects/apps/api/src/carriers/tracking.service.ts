import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { NotificationProducer } from '../notifications/notification.producer';

export const CarrierScanSchema = z.object({
  carrier: z.string(),
  trackingNo: z.string(),
  status: z.string(),
  scannedAt: z.string(),
  merchantUserId: z.string(),
});
export type CarrierScan = z.infer<typeof CarrierScanSchema>;

@Injectable()
export class TrackingService {
  constructor(
    private readonly em: EntityManager,
    private readonly notifications: NotificationProducer,
  ) {}

  /** Appends the scan to the shipment's history and pushes "parcel moved" to the merchant's app. */
  async applyScan(scan: CarrierScan): Promise<void> {
    await this.em.getConnection().execute(
      'INSERT INTO tracking_history (carrier, tracking_no, status, scanned_at) VALUES (?, ?, ?, ?)',
      [scan.carrier, scan.trackingNo, scan.status, scan.scannedAt],
    );
    await this.notifications.push({ userId: scan.merchantUserId, title: `Parcel ${scan.trackingNo}`, body: scan.status });
  }
}
