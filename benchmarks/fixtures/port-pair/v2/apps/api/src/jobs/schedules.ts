import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { StockFeedExport } from '../inventory/stock-feed.export';
import { StockReservationService } from '../inventory/stock-reservation.service';
import { WalletsService } from '../wallets/wallets.service';

// Ported entries of V1 routes/console.php. The weekly sales report runs as a Kubernetes CronJob
// (deploy/k8s/cronjobs/weekly-report.yaml); the nightly invoice run is in invoice-schedules.ts.
@Injectable()
export class Schedules {
  constructor(private readonly stockFeed: StockFeedExport, private readonly wallets: WalletsService, private readonly reservations: StockReservationService) {}

  @Cron('0 0 5 * * *', { name: 'stock-export-feed', timeZone: 'Asia/Riyadh' })
  async exportStockFeed(): Promise<void> {
    await this.stockFeed.run();
  }
}
