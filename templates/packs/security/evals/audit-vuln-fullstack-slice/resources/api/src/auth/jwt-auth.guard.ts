import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { readFileSync } from 'fs';
import * as jwt from 'jsonwebtoken';
import { config } from '../config';
import { AuthUser } from './auth.dto';

// Bearer-token guard for every SPA-facing route.
@Injectable()
export class JwtAuthGuard implements CanActivate {
  private readonly publicKey = readFileSync(config.auth.publicKeyPath, 'utf8');

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    const header: string = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token) throw new UnauthorizedException();

    try {
      req.user = jwt.verify(token, this.publicKey) as AuthUser;
      return true;
    } catch {
      throw new UnauthorizedException();
    }
  }
}
