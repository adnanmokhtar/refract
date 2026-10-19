import { Injectable } from '@nestjs/common';
import { pbkdf2, pbkdf2Sync, randomBytes, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

// OWASP 2023 guidance for PBKDF2-HMAC-SHA512.
const ITERATIONS = 600_000;
const KEY_LENGTH = 64;
const DIGEST = 'sha512';

const pbkdf2Async = promisify(pbkdf2);

// Stored format: pbkdf2$<iterations>$<salt b64>$<hash b64>
@Injectable()
export class PasswordService {
  // Sign-up, password change and the re-hash of legacy accounts.
  async hash(password: string): Promise<string> {
    const salt = randomBytes(16);
    const derived = await pbkdf2Async(password, salt, ITERATIONS, KEY_LENGTH, DIGEST);
    return `pbkdf2$${ITERATIONS}$${salt.toString('base64')}$${derived.toString('base64')}`;
  }

  // Accounts created before 2023 carry 100 k-iteration hashes; AuthService re-hashes them on
  // the next successful login.
  needsRehash(stored: string): boolean {
    const [, iterations] = stored.split('$');
    return Number(iterations) < ITERATIONS;
  }

  // POST /auth/login, and the "confirm your password" step before payout-detail changes.
  verify(password: string, stored: string): boolean {
    const [scheme, iterations, saltB64, hashB64] = stored.split('$');
    if (scheme !== 'pbkdf2') return false;
    const rounds = Number(iterations);
    const salt = Buffer.from(saltB64, 'base64');
    const expected = Buffer.from(hashB64, 'base64');
    const actual = pbkdf2Sync(password, salt, rounds, KEY_LENGTH, DIGEST);
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  }
}
