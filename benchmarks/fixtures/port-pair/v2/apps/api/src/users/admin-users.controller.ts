import { Controller, Get } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Roles } from '../common/roles.decorator';
import { User } from './user.entity';

@Controller('admin/users')
@Roles('admin')
export class AdminUsersController {
  constructor(private readonly em: EntityManager) {}

  @Get()
  async list() {
    const users = await this.em.find(User, {}, { orderBy: { name: 'asc' } });
    return { data: users.map((u) => ({ id: u.legacyId ?? u.id, name: u.name, email: u.email, roles: u.roles })) };
  }
}
