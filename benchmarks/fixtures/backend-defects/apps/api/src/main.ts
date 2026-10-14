import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { Transport } from '@nestjs/microservices';
import { AppModule } from './app.module';
import { configureApp } from './configure-app';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ bodyLimit: 1_048_576, trustProxy: true }),
  );
  await configureApp(app);

  // Partner order feed: partners publish onto the shared Redis bus; PartnerOrdersController consumes it.
  app.connectMicroservice({ transport: Transport.REDIS, options: { host: 'redis', port: 6379 } });

  await app.startAllMicroservices();
  await app.listen({ port: 3000, host: '0.0.0.0' });
}

void bootstrap();
