import { NestFactory } from '@nestjs/core';
import { WorkerModule } from './worker.module';
import { SchedulerModule } from './scheduler.module';

/** One image, two roles: `--role=consumers` (processors and consumers) and `--role=scheduler` (crons, one pod). */
async function bootstrap(): Promise<void> {
  const role = process.argv.find((a) => a.startsWith('--role='))?.slice('--role='.length) ?? 'consumers';
  const app = await NestFactory.createApplicationContext(role === 'scheduler' ? SchedulerModule : WorkerModule);
  app.enableShutdownHooks();
}

void bootstrap();
