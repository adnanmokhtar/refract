import { NestFactory } from '@nestjs/core';
import { WINSTON_MODULE_NEST_PROVIDER } from 'nest-winston';
import { WorkerModule } from './worker.module';
import { startMetricsServer } from './metrics';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
  app.useLogger(app.get(WINSTON_MODULE_NEST_PROVIDER));
  app.enableShutdownHooks();
  startMetricsServer(Number(process.env.METRICS_PORT ?? 9464));
}

void bootstrap();
