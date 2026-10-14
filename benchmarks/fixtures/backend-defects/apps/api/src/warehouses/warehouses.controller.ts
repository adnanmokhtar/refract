import { Body, Controller, Param, Put } from '@nestjs/common';
import { EntityManager, Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { NotFoundError } from '../common/errors';
import { UpdateWarehouseDto } from './dto/update-warehouse.dto';

@Entity({ tableName: 'warehouses' })
export class Warehouse {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  name!: string;

  @Property({ nullable: true })
  address?: string;

  @Property()
  timeZone: string = 'Asia/Dubai';
}

@Controller('warehouses')
export class WarehousesController {
  constructor(private readonly em: EntityManager) {}

  /** openapi: PUT replaces the warehouse representation. */
  @Put(':id')
  async replace(@Param('id') id: string, @Body() dto: UpdateWarehouseDto): Promise<Warehouse> {
    const warehouse = await this.em.findOne(Warehouse, { id });
    if (!warehouse) throw new NotFoundError('Warehouse', id);
    Object.assign(warehouse, dto);
    await this.em.flush();
    return warehouse;
  }
}
