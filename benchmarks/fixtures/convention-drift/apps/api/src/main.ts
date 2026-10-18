import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, type NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from './app.module';
import { ProblemDetailsFilter } from './common/problem-details.filter';
import { OrdersRepository } from './orders/orders.repository';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter());
  app.setGlobalPrefix('api/v2');
  app.useGlobalFilters(new ProblemDetailsFilter());
  await app.get(OrdersRepository).warmStatusCache();
  await app.listen({ port: 3000, host: '0.0.0.0' });
}

void bootstrap();
