import { Injectable } from '@nestjs/common';

@Injectable()
export class InvoicesService {
  async list(cursor: string | undefined, limit: number) {
    return { items: [] as Array<{ id: string }>, nextCursor: cursor ? null : null, limit };
  }
}
