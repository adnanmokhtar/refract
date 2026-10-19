import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Request } from 'express';
import * as jwt from 'jsonwebtoken';
import { AuthUser } from './auth.dto';

// Staff-only routes. Used on its own, without JwtAuthGuard: tokens were already checked
// upstream, so all this needs is the role claim.
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request & { user?: AuthUser }>();
    const token = (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '');
    if (!token) return false;

    const claims = jwt.decode(token) as AuthUser | null;
    if (claims?.role !== 'ADMIN') return false;

    req.user = claims;
    return true;
  }
}
