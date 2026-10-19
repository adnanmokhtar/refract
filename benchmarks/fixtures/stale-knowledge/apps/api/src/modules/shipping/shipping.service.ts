import { Injectable, NotFoundException } from '@nestjs/common';

@Injectable()
export class ShippingService {
  private readonly rows = new Map<string, { id: string }>();

  async get(id: string): Promise<{ id: string }> {
    const row = this.rows.get(id);
    if (!row) {
      throw new NotFoundException(`shipping ${id} not found`);
    }
    return row;
  }
}
