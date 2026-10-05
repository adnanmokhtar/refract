import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { RenewalController } from './renewal.controller';
import { RenewalService } from './renewal.service';
import { PlanChangeService } from './plan-change.service';

@Module({
  imports: [BillingModule],
  controllers: [RenewalController],
  providers: [RenewalService, PlanChangeService],
})
export class SubscriptionsModule {}
