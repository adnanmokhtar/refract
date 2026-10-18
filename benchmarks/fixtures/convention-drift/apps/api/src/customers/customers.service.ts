import { Injectable } from '@nestjs/common';

@Injectable()
export class CustomersService {
  async list(page: number, size: number) {
    return { items: [] as Array<{ id: string }>, page, size, total: 0 };
  }
}
