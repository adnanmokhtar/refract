import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { HousekeepingCron } from './schedules/housekeeping.cron';
import { EtaRecomputeCron } from './schedules/eta-recompute.cron';
import { CarrierCutoffCron } from './schedules/carrier-cutoff.cron';

@Module({
  imports: [MikroOrmModule.forRoot(), ScheduleModule.forRoot()],
  providers: [HousekeepingCron, EtaRecomputeCron, CarrierCutoffCron],
})
export class SchedulerModule {}
