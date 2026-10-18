import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { verify } from '../common/password';
import { User } from '../users/user.entity';

@Injectable()
export class CredentialsService {
  constructor(private readonly em: EntityManager) {}

  // V1: User::where('email', strtolower($email)) + Hash::check (bcrypt hashes are shared).
  async verify(email: string, password: string): Promise<User | null> {
    const user = await this.em.findOne(User, { email: email.toLowerCase() }, { filters: false });
    return user && (await verify(password, user.passwordHash)) ? user : null;
  }

  async issueToken(user: User, deviceName: string): Promise<string> {
    const [{ token }] = await this.em.getConnection().execute<{ token: string }[]>(
      'select issue_personal_access_token(?, ?) as token',
      [user.legacyId ?? user.id, deviceName],
    );
    return token;
  }
}
