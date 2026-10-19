import { Injectable, NotFoundException } from '@nestjs/common';

@Injectable()
export class InventoryService {
  private readonly rows = new Map<string, { id: string }>();

  async get(id: string): Promise<{ id: string }> {
    const row = this.rows.get(id);
    if (!row) {
      throw new NotFoundException(`inventory ${id} not found`);
    }
    return row;
  }
}
