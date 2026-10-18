import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { EntityManager } from '@mikro-orm/postgresql';
import { IS_PUBLIC } from './public.decorator';
import { SessionStore } from './session-store';

// Registered as APP_GUARD: every route is authenticated unless it carries @Public().
// Accepts a Sanctum-compatible bearer token or the shared `norrow_session` cookie.
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly sessions: SessionStore, private readonly em: EntityManager) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()])) {
      return true;
    }

    const req = ctx.switchToHttp().getRequest();
    const user = await this.sessions.resolve(req.headers.authorization, req.cookies?.norrow_session);
    if (!user) {
      throw new UnauthorizedException({ message: 'Unauthenticated.' });
    }

    req.user = user;
    this.em.setFilterParams('account', { accountId: user.accountId });
    return true;
  }
}
