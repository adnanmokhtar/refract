import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { AuthUser } from '../auth/auth-user';
import { StoreMember } from './store-member.entity';

// Allows the request when the caller is a member (any role) of the :storeId in the route.
@Injectable()
export class StoreStaffGuard implements CanActivate {
  constructor(private readonly em: EntityManager) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<{ user?: AuthUser; params: Record<string, string> }>();
    if (!req.user) return false;
    const member = await this.em.findOne(StoreMember, { store: req.params.storeId, user: req.user.id }, { fields: ['id'] });
    if (!member) throw new ForbiddenException();
    return true;
  }
}
