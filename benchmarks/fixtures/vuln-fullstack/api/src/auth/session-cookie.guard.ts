import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Request } from 'express';
import { config } from '../config';
import { PrismaService } from '../prisma/prisma.service';

export type SessionRequest = Request & { session?: { userId: string; sessionId: string } };

// Cookie-session guard for the account pages.
@Injectable()
export class SessionCookieGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<SessionRequest>();
    const sessionId = req.cookies?.[config.auth.sessionCookie];
    if (!sessionId) throw new UnauthorizedException();

    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, revokedAt: null, expiresAt: { gt: new Date() } },
    });
    if (!session) throw new UnauthorizedException();

    req.session = { userId: session.userId, sessionId: session.id };
    return true;
  }
}
