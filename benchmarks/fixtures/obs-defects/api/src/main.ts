import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { Logger } from 'nestjs-pino';
import './tracing';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/all-exceptions.filter';
import { HttpExceptionFilter } from './common/http-exception.filter';
import { registerHttpMetrics } from './metrics/http-metrics.hook';
import { registerSlowRequestCounter } from './metrics/slow-request.hook';

async function bootstrap(): Promise<void> {
  const adapter = new FastifyAdapter({
    trustProxy: true,
    bodyLimit: 1_048_576,
  });

  const app = await NestFactory.create<NestFastifyApplication>(AppModule, adapter);

  // The catch-everything filter goes first so the HttpException filter is tried before it.
  app.useGlobalFilters(new AllExceptionsFilter(), new HttpExceptionFilter(app.get(Logger)));
  registerHttpMetrics(app.getHttpAdapter().getInstance());
  registerSlowRequestCounter(app.getHttpAdapter().getInstance());
  app.enableShutdownHooks();

  process.on('unhandledRejection', (reason) => {
    app.get(Logger).error({ err: reason }, 'unhandled rejection');
  });

  await app.listen({ port: Number(process.env.PORT ?? 3000), host: '0.0.0.0' });
}

void bootstrap();
