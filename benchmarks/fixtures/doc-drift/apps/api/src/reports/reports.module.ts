import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';

import { ReportsController } from './reports.controller';
import { ReportsDailyProcessor } from './reports.processor';
import { ReportsService } from './reports.service';

@Module({
  imports: [BullModule.registerQueue({ name: 'reports' })],
  controllers: [ReportsController],
  providers: [ReportsService, ReportsDailyProcessor],
})
export class ReportsModule {}
