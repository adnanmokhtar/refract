import { Injectable, UnauthorizedException } from '@nestjs/common';

export interface Session {
  tenantId: string;
  agentId: string;
  roles: string[];
}

@Injectable()
export class SessionVerifier {
  async verify(token: string): Promise<Session> {
    const res = await fetch(`${process.env.AUTH_URL}/sessions/introspect`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token }),
    });
    if (!res.ok) throw new UnauthorizedException();
    return (await res.json()) as Session;
  }
}
