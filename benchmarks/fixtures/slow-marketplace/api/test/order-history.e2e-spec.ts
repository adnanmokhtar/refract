import { Test } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import ormConfig from '../src/config/mikro-orm.config';
import { OrdersModule } from '../src/orders/orders.module';
import { QueryCounter } from './query-counter';
import { seedStoreWithOrders } from './seed';

describe('GET /me/orders', () => {
  const counter = new QueryCounter();
  let app: NestFastifyApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        MikroOrmModule.forRoot({ ...ormConfig, dbName: process.env.TEST_DATABASE_NAME ?? 'stallwise_e2e', replicas: [], debug: ['query'], loggerFactory: () => counter }),
        OrdersModule,
      ],
    }).compile();
    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(() => app.close());

  it('returns the newest 20 orders with their lines', async () => {
    const { customerIds } = await seedStoreWithOrders(app, { orders: 25, linesPerOrder: 3 });
    counter.reset();
    const res = await app.inject({ method: 'GET', url: '/me/orders', headers: { 'x-test-customers': customerIds.join(',') } });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toHaveLength(20);
  });
});
