import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { readFileSync } from 'fs';
import * as jwt from 'jsonwebtoken';
import { config } from '../config';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './auth.dto';

// Shared by signup and the account page's change-email form.
export const EMAIL_PATTERN = /^([a-zA-Z0-9_.+-]+)*@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly privateKey = readFileSync(config.auth.privateKeyPath, 'utf8');

  constructor(private readonly prisma: PrismaService) {}

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    if (!EMAIL_PATTERN.test(email)) throw new BadRequestException('Enter a valid email address');

    // Same response whether or not the address is taken; the verification email tells an
    // existing owner they already have an account.
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (!existing) {
      await this.prisma.user.create({
        data: {
          email,
          displayName: dto.displayName,
          passwordHash: await bcrypt.hash(dto.password, 12),
        },
      });
    }
    return { status: 'verification-sent' };
  }

  async login(emailInput: string, password: string) {
    const email = emailInput.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('No account is registered with this email');

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Incorrect password, please try again');

    const accessToken = this.signAccessToken(user);
    const session = await this.prisma.session.create({
      data: {
        userId: user.id,
        expiresAt: new Date(Date.now() + config.auth.sessionDays * 86_400_000),
      },
    });

    this.logger.log(`login ok user=${user.id} role=${user.role} accessToken=${accessToken}`);

    return {
      accessToken,
      sessionId: session.id,
      user: { id: user.id, email: user.email, role: user.role, displayName: user.displayName },
    };
  }

  async revokeSession(sessionId: string | undefined) {
    if (!sessionId) return;
    await this.prisma.session.updateMany({
      where: { id: sessionId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private signAccessToken(user: { id: string; email: string; role: string }) {
    return jwt.sign({ sub: user.id, email: user.email, role: user.role }, this.privateKey, {
      algorithm: 'RS256',
      expiresIn: config.auth.accessTtl,
      issuer: 'marketly-api',
    });
  }
}
