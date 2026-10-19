import { Body, Controller, Get, Param, Patch } from '@nestjs/common';
import { CategoryPathService } from './category-path';
import { CategoryPathsRepository } from './category-paths.repository';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Controller('stores/:storeId/categories')
export class CategoriesController {
  constructor(
    private readonly paths: CategoryPathService,
    private readonly subtree: CategoryPathsRepository,
  ) {}

  @Patch(':id')
  update(@Param('storeId') storeId: string, @Param('id') id: string, @Body() dto: UpdateCategoryDto) {
    return this.paths.update(storeId, id, dto);
  }

  @Get(':id/root')
  root(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.paths.rootCategory(storeId, id);
  }

  @Get(':id/subtree')
  descendants(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.subtree.subtreePaths(storeId, id);
  }
}
