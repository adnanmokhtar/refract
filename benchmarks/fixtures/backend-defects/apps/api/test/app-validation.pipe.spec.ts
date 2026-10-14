import { ValidationPipe } from '@nestjs/common';
import { WriteCollectionDto } from '../src/pricing/dto/write-collection.dto';

describe('AppValidationPipe options', () => {
  // Same options as AppValidationPipe; the e2e suite runs the real AppModule.
  const pipe = new ValidationPipe({ transform: true, whitelist: true });

  it('rejects a title over 80 chars', async () => {
    await expect(pipe.transform({ title: 'x'.repeat(81), items: [] }, { type: 'body', metatype: WriteCollectionDto })).rejects.toBeDefined();
  });
});
