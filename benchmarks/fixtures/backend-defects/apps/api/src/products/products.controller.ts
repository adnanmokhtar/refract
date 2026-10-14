import { Body, Controller, Param, Patch, Post, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { UpdateProductUseCase } from './update-product.use-case';
import { Product } from './product.entity';

@Controller('products')
export class ProductsController {
  constructor(private readonly updateProduct: UpdateProductUseCase) {}

  @Post()
  async create(@Body() dto: CreateProductDto, @Res({ passthrough: true }) reply: FastifyReply): Promise<{ id: string }> {
    const id = crypto.randomUUID();
    reply.status(201).header('Location', `/v1/products/${id}`);
    return { id };
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateProductDto): Promise<Product> {
    return this.updateProduct.execute(id, dto);
  }
}
