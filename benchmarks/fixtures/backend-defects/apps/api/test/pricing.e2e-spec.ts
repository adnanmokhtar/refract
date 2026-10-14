import { Test } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';

describe('pricing (e2e, real bootstrap)', () => {
  let app: NestFastifyApplication;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    await configureApp(app);
    await app.init();
  });

  it('rejects a non-UUID rate card id', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/pricing/rate-cards/apply', payload: { rateCardId: 'x', orderId: 'y' } });
    expect(res.statusCode).toBe(400);
  });
});
