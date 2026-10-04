import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { createHmac, randomBytes } from 'node:crypto';
import { env } from '../common/env';
import { PasswordService } from './password.service';

// The dummy hash keeps the miss path as slow as the hit path (no account enumeration by timing).
const DUMMY_HASH = `pbkdf2$600000$${Buffer.alloc(16).toString('base64')}$${Buffer.alloc(64).toString('base64')}`;

@Injectable()
export class AuthService {
  constructor(
    private readonly em: EntityManager,
    private readonly passwords: PasswordService,
  ) {}

  async login(email: string, password: string): Promise<{ sessionId: string } | null> {
    const [row] = await this.em.execute<{ id: string; password_hash: string }[]>(
      'select id, password_hash from user_credential where email = lower(?)',
      [email],
    );
    const ok = this.passwords.verify(password, row?.password_hash ?? DUMMY_HASH);
    if (!row || !ok) return null;

    if (this.passwords.needsRehash(row.password_hash)) {
      const fresh = await this.passwords.hash(password);
      await this.em.execute('update user_credential set password_hash = ? where id = ?', [fresh, row.id]);
    }

    const sessionId = randomBytes(32).toString('base64url');
    const digest = createHmac('sha256', env('SESSION_PEPPER')).update(sessionId).digest('hex');
    await this.em.execute('insert into session (id_digest, user_id, expires_at) values (?, ?, now() + interval \'14 days\')', [digest, row.id]);
    return { sessionId };
  }
}
