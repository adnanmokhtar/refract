import { Injectable, NotFoundException } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Category } from './category.entity';
import { UpdateCategoryDto } from './dto/update-category.dto';

/** The top-level category a category sits under (the storefront's department tabs). */
const rootOf = (c: Category): Category => (c.parent ? rootOf(c.parent) : c);

@Injectable()
export class CategoryPathService {
  constructor(private readonly em: EntityManager) {}

  async rootCategory(storeId: string, id: string): Promise<{ id: string; name: string }> {
    const all = await this.em.find(Category, { store: storeId });
    const start = all.find((c) => c.id === id);
    if (!start) {
      throw new NotFoundException();
    }
    const root = rootOf(start);
    return { id: root.id, name: root.name };
  }

  async update(storeId: string, id: string, dto: UpdateCategoryDto): Promise<Category> {
    const category = await this.em.findOneOrFail(Category, { id, store: storeId });
    if (dto.name !== undefined) category.name = dto.name;
    if (dto.position !== undefined) category.position = dto.position;
    if (dto.parentId !== undefined) {
      category.parent = dto.parentId ? this.em.getReference(Category, dto.parentId) : null;
    }
    await this.em.flush();
    return category;
  }
}
