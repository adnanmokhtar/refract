import { Module } from '@nestjs/common';
import { OrdersModule } from '../orders/orders.module';
import { PayoutsModule } from '../payouts/payouts.module';
import { InboxClient } from './inbox.client';
import { SalesStatsService } from './sales-stats.service';
import { SellerDashboardService } from './seller-dashboard.service';

@Module({
  imports: [OrdersModule, PayoutsModule],
  providers: [SellerDashboardService, SalesStatsService, InboxClient],
})
export class DashboardModule {}
