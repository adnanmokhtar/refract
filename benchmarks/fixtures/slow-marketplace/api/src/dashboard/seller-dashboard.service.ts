import { Injectable } from '@nestjs/common';
import { SellerOrdersService } from '../orders/seller-orders.service';
import { PayoutLedgerService } from '../payouts/payout-ledger.service';
import { InboxClient } from './inbox.client';
import { DateRange, SalesStatsService } from './sales-stats.service';

@Injectable()
export class SellerDashboardService {
  constructor(
    private readonly stats: SalesStatsService,
    private readonly orders: SellerOrdersService,
    private readonly payouts: PayoutLedgerService,
    private readonly inbox: InboxClient,
  ) {}

  // GET /stores/:storeId/dashboard — the first screen a seller sees after signing in; the
  // dashboard re-polls it every 30 s while open.
  async overview(storeId: string, range: DateRange) {
    const sales = await this.stats.salesSummary(storeId, range);
    const openOrders = await this.orders.countOpen(storeId);
    const payouts = await this.payouts.payoutsForStore(storeId, 5);
    const unreadMessages = await this.inbox.unreadCount(storeId);

    return {
      sales,
      openOrders,
      nextPayout: payouts.find((p) => p.status === 'scheduled') ?? null,
      lastPayout: payouts.find((p) => p.status === 'paid') ?? null,
      unreadMessages,
    };
  }
}
