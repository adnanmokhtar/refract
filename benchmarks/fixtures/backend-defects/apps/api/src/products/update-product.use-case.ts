import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { NotFoundError } from '../common/errors';
import { Product } from './product.entity';
import { UpdateProductDto } from './dto/update-product.dto';

@Injectable()
export class UpdateProductUseCase {
  constructor(private readonly em: EntityManager) {}

  async execute(id: string, dto: UpdateProductDto): Promise<Product> {
    const product = await this.em.findOne(Product, { id });
    if (!product) throw new NotFoundError('Product', id);
    if (dto.name !== undefined) product.rename(dto.name);
    if (dto.stockLevel !== undefined) product.stockLevel = dto.stockLevel;
    await this.em.flush();
    return product;
  }
}
