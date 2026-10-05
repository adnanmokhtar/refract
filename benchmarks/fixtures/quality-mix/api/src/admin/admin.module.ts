import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { AdminOpsService } from './admin-ops.service';

@Module({ imports: [BillingModule], providers: [AdminOpsService] })
export class AdminModule {}
