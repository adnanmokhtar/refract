import { Test } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from '../../src/app.module';

export async function bootApp(): Promise<NestFastifyApplication> {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
  app.setGlobalPrefix('api');
  await app.init();
  await app.getHttpAdapter().getInstance().ready();
  return app;
}

export async function paidOrder(app: NestFastifyApplication, lines = 3) {
  const res = await app.inject({ method: 'POST', url: '/api/orders', payload: { lines: Array.from({ length: lines }, (_, i) => ({ sku: `SKU-${i}`, qty: 1 })) } });
  return res.json() as { id: string; lines: { id: string }[] };
}
