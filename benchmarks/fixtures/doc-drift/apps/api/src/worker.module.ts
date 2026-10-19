import { Module } from '@nestjs/common';

import { ReportsModule } from './reports/reports.module';
import { WebhooksModule } from './webhooks/webhooks.module';

@Module({ imports: [WebhooksModule, ReportsModule] })
export class WorkerModule {}
