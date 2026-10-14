import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { LeaderLock } from '../locks/leader-lock';
import { CodSettlement } from './cod-settlement.service';

/**
 * Nightly cash-on-delivery settlement: collects the previous day's COD amounts per merchant and books the
 * transfers. One api replica runs it (leader key, 10-minute TTL; the run takes 3–4 minutes).
 */
@Injectable()
export class SettlementCron {
  constructor(
    private readonly leader: LeaderLock,
    private readonly settlement: CodSettlement,
  ) {}

  @Cron('0 30 2 * * *')
  async settleYesterday(): Promise<void> {
    await this.leader.withLeaderLock('cron:cod-settlement', 10 * 60_000, () => this.settlement.settleDay(new Date()));
  }
}
