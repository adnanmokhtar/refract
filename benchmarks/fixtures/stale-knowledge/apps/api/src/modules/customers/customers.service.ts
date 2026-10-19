import { Injectable, NotFoundException } from '@nestjs/common';

@Injectable()
export class CustomersService {
  private readonly rows = new Map<string, { id: string }>();

  async get(id: string): Promise<{ id: string }> {
    const row = this.rows.get(id);
    if (!row) {
      throw new NotFoundException(`customer ${id} not found`);
    }
    return row;
  }
}
