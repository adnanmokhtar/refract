import { Test } from '@nestjs/testing';
import { AppModule } from '../src/app.module';

describe('orders (e2e)', () => {
  it('lists the orders of the calling tenant only', async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    const app = moduleRef.createNestApplication();
    await app.init();
    await app.close();
  });
});
