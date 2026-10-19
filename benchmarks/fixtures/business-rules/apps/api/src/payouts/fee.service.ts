import Decimal from 'decimal.js';
import { Injectable } from '@nestjs/common';
import { FeeSchedule } from './fee-schedule.entity';
import { roundHalfAwayFromZero } from '../money/money-policy';

@Injectable()
export class FeeService {
  platformFeeMinor(orderNetMinor: number, schedule: FeeSchedule): number {
    const raw = new Decimal(orderNetMinor).mul(new Decimal(schedule.feeRate));
    return roundHalfAwayFromZero(raw.toNumber());
  }
}
