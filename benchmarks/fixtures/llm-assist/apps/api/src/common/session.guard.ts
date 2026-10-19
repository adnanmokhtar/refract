import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import type { AuthedRequest } from './authed-request';

/** The session cookie is resolved by the auth middleware; this guard only requires it. */
@Injectable()
export class SessionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    if (!req.user?.tenantId) throw new UnauthorizedException();
    return true;
  }
}
