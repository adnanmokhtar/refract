import { Injectable } from '@nestjs/common';

@Injectable()
export class ProductsService {
  async list(cursor: string | undefined, limit: number) {
    return { items: [] as Array<{ id: string }>, nextCursor: cursor ? null : null, limit };
  }
}
