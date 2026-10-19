import { Injectable, NotFoundException } from '@nestjs/common';

@Injectable()
export class CatalogService {
  private readonly rows = new Map<string, { id: string }>();

  async get(id: string): Promise<{ id: string }> {
    const row = this.rows.get(id);
    if (!row) {
      throw new NotFoundException(`catalog ${id} not found`);
    }
    return row;
  }
}
