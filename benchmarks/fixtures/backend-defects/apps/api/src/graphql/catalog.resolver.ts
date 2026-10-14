import { Args, Parent, Query, ResolveField, Resolver } from '@nestjs/graphql';
import { EntityManager } from '@mikro-orm/core';
import { productLoader } from './loaders';

@Resolver('Category')
export class CatalogResolver {
  constructor(private readonly em: EntityManager) {}

  @Query('category')
  async category(@Args('id') id: string): Promise<unknown> {
    const [row] = await this.em.getConnection().execute('select id, name from categories where id = ?', [id]);
    return row ?? null;
  }

  @ResolveField('products')
  async products(@Parent() category: { id: string }): Promise<unknown[]> {
    const rows = await this.em.getConnection().execute('select product_id from category_products where category_id = ?', [category.id]);
    return productLoader.loadMany(rows.map((r: { product_id: string }) => r.product_id));
  }
}
