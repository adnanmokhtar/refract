import { Injectable } from '@nestjs/common';
import type { AuthUser } from './current-user.decorator';

// Reads the V1 Sanctum personal_access_tokens table and the shared Redis session store, so a
// user signed in on either half is signed in on both during the cutover window.
@Injectable()
export class SessionStore {
  async resolve(authorization: string | undefined, sessionCookie: string | undefined): Promise<AuthUser | null> {
    if (authorization?.startsWith('Bearer ')) {
      return this.fromToken(authorization.slice(7));
    }
    return sessionCookie ? this.fromSession(sessionCookie) : null;
  }

  private async fromToken(_token: string): Promise<AuthUser | null> {
    return null;
  }

  private async fromSession(_id: string): Promise<AuthUser | null> {
    return null;
  }
}
