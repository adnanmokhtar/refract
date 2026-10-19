import { Injectable } from '@nestjs/common';

export interface WeeklyInsight {
  metric: 'revenue' | 'orders' | 'stockouts';
  change: number;
  label: string;
}

@Injectable()
export class InsightsService {
  /** The three dashboard cards: week over week. */
  weekly(tenantId: string): WeeklyInsight[] {
    void tenantId;
    return [
      { metric: 'revenue', change: 12.5, label: 'Revenue is up 12.5% on last week' },
      { metric: 'orders', change: -3, label: 'Orders are down 3% on last week' },
      { metric: 'stockouts', change: 2, label: '2 more products ran out of stock' },
    ];
  }
}
