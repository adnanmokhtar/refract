import { Args, Context, Field, Float, ID, Int, ObjectType, Parent, Query, ResolveField, Resolver } from '@nestjs/graphql';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Store } from '../stores/store.entity';
import { Product } from './product.entity';
import { ProductLoaders } from './product-loaders';

@ObjectType('Store')
export class StoreModel {
  @Field(() => ID) id!: string;
  @Field() slug!: string;
  @Field() name!: string;
}

@ObjectType('Brand')
export class BrandModel {
  @Field(() => ID) id!: string;
  @Field() name!: string;
  @Field({ nullable: true }) logoUrl?: string;
}

@ObjectType('Product')
export class ProductModel {
  @Field(() => ID) id!: string;
  @Field() slug!: string;
  @Field() title!: string;
  @Field(() => Float) price!: number;
  @Field() currency!: string;
}

// Public GraphQL catalog, used by the mobile apps and partner storefronts.
@Resolver(() => ProductModel)
export class ProductResolver {
  constructor(private readonly em: EntityManager) {}

  @Query(() => [ProductModel])
  async products(
    @Args('category') category: string,
    @Args('first', { type: () => Int, defaultValue: 24 }) first: number,
  ): Promise<Product[]> {
    return this.em.find(
      Product,
      { category, status: 'active' },
      { orderBy: { createdAt: QueryOrder.DESC }, limit: Math.min(Math.max(first, 1), 100) },
    );
  }

  @ResolveField(() => StoreModel)
  async store(@Parent() product: Product): Promise<Store> {
    return this.em.findOneOrFail(Store, { id: product.store.id });
  }

  @ResolveField(() => Int)
  async stock(@Parent() product: Product): Promise<number> {
    return Math.max(product.stock, 0);
  }

  @ResolveField(() => String, { nullable: true })
  async category(@Parent() product: Product): Promise<string | null> {
    return product.category ?? null;
  }

  @ResolveField(() => BrandModel, { nullable: true })
  async brand(@Parent() product: Product, @Context('loaders') loaders: ProductLoaders) {
    if (!product.brandId) return null;
    return loaders.brandById.load(product.brandId);
  }
}
