import { Injectable } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { Mailer } from '../notifications/mailer';

/** New merchant accounts: the owner must verify the e-mail before the store can take payments. */
@Injectable()
export class SignupService {
  constructor(private readonly mailer: Mailer) {}

  async signUp(email: string): Promise<{ userId: string }> {
    const userId = randomBytes(8).toString('hex');
    const token = randomBytes(24).toString('base64url');
    await this.mailer.sendVerificationEmail(email, token);
    return { userId };
  }
}
