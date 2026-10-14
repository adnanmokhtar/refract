import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { Principal } from '../common/current-user.decorator';
import { WriteCollectionDto } from './dto/write-collection.dto';

@Injectable()
export class CollectionsService {
  constructor(private readonly em: EntityManager) {}

  async write(user: Principal, id: string, dto: WriteCollectionDto | null): Promise<{ id: string }> {
    const items = dto?.items ?? [];
    await this.em.getConnection().execute('delete from collection_items where collection_id = ?', [id]);
    for (const item of items) {
      await this.em.getConnection().execute('insert into collection_items (collection_id, product_id, tenant_id) values (?, ?, ?)', [id, item.productId, user.tenantId]);
    }
    return { id };
  }

  async remove(id: string): Promise<void> {
    await this.em.getConnection().execute('delete from collections where id = ?', [id]);
  }
}
