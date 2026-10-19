import { Injectable } from '@nestjs/common';

@Injectable()
export class SessionService {
  async fromCookie(cookie?: string): Promise<{ id: string; tenantId: string } | null> {
    return cookie ? { id: 'u', tenantId: 't' } : null;
  }
}
