import { HttpException, HttpStatus, Injectable } from '@nestjs/common';

const WINDOW_MS = 15 * 60_000;
const MAX_ATTEMPTS = 10;

// Brute-force protection for POST /auth/login: at most 10 failed attempts per account email
// in any 15-minute window, after which the account is locked out until the window clears.
@Injectable()
export class LoginRateLimiter {
  private readonly attempts = new Map<string, number[]>();

  assertAllowed(email: string): void {
    const recent = this.recent(email);
    if (recent.length >= MAX_ATTEMPTS) {
      throw new HttpException('Too many failed attempts. Try again in 15 minutes.', HttpStatus.TOO_MANY_REQUESTS);
    }
  }

  recordFailure(email: string): void {
    const recent = this.recent(email);
    recent.push(Date.now());
    this.attempts.set(email.toLowerCase(), recent);
  }

  recordSuccess(email: string): void {
    this.attempts.delete(email.toLowerCase());
  }

  private recent(email: string): number[] {
    const key = email.toLowerCase();
    const cutoff = Date.now() - WINDOW_MS;
    const kept = (this.attempts.get(key) ?? []).filter((t) => t > cutoff);
    if (kept.length === 0) this.attempts.delete(key);
    return kept;
  }
}
