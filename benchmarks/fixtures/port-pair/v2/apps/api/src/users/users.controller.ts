import { Body, Controller, Get, Param, ParseIntPipe, Put } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { Roles } from '../common/roles.decorator';
import { ZodValidationPipe } from '../common/zod';
import { User } from './user.entity';

const SyncRolesBody = z.object({ roles: z.array(z.enum(['admin', 'manager', 'agent', 'clerk'])).min(1) });

// User detail and role assignment, split out of the admin controller in the port.
@Controller('admin/users')
export class UsersController {
  constructor(private readonly em: EntityManager) {}

  @Get(':id')
  @Roles('admin')
  async get(@Param('id', ParseIntPipe) id: number) {
    const u = await this.em.findOneOrFail(User, { legacyId: id });
    return { data: { id: u.legacyId, name: u.name, email: u.email, roles: u.roles } };
  }

  @Put(':id/roles')
  async syncRoles(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(SyncRolesBody)) body: { roles: string[] }) {
    const u = await this.em.findOneOrFail(User, { legacyId: id });
    u.roles = body.roles;
    await this.em.flush();
    return { data: { id: u.legacyId, name: u.name, email: u.email, roles: u.roles } };
  }
}
