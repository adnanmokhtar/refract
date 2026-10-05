import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { SessionVerifier } from './session-verifier';

export interface TenantRequest extends FastifyRequest {
  tenantId: string;
  agentId: string;
  roles: string[];
}

@Injectable()
export class TenantGuard implements CanActivate {
  constructor(private readonly sessions: SessionVerifier) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<TenantRequest>();
    if (process.env.NODE_ENV === 'test') {
      // e2e runs have no auth service: take the identity from headers the test sets.
      req.tenantId = String(req.headers['x-test-tenant'] ?? 'tn_test');
      req.agentId = String(req.headers['x-test-agent'] ?? 'agent_test');
      req.roles = String(req.headers['x-test-roles'] ?? '').split(',').filter(Boolean);
      return true;
    }

    const token = req.headers.authorization?.replace(/^Bearer /, '');
    if (!token) throw new UnauthorizedException();
    const session = await this.sessions.verify(token);
    req.tenantId = session.tenantId;
    req.agentId = session.agentId;
    req.roles = session.roles;
    return true;
  }
}
