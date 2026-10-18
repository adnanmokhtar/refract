import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ReportsService } from './reports/reports.service';

// One-shot commands for Kubernetes CronJobs: `node dist/cli.js <command>`.
async function main(command: string | undefined): Promise<void> {
  const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error', 'warn'] });
  try {
    if (command === 'reports:email-weekly') {
      await app.get(ReportsService).emailWeekly();
    } else {
      throw new Error(`unknown command: ${command ?? '(none)'}`);
    }
  } finally {
    await app.close();
  }
}

void main(process.argv[2]);
