import { BadRequestException, Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { EMAIL_PATTERN } from '../auth/auth.service';
import { SessionCookieGuard, SessionRequest } from '../auth/session-cookie.guard';
import { PrismaService } from '../prisma/prisma.service';

// The account pages are plain HTML forms posted straight to these routes, authenticated by
// the session cookie set at login.
@Controller('account')
@UseGuards(SessionCookieGuard)
export class AccountController {
  constructor(private readonly prisma: PrismaService) {}

  @Post('payout-account')
  async setPayoutAccount(@Req() req: SessionRequest, @Body() body: { iban: string; holder: string }) {
    const iban = String(body.iban ?? '').replace(/\s+/g, '').toUpperCase();
    if (!/^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/.test(iban)) throw new BadRequestException('Invalid IBAN');
    await this.prisma.payoutAccount.upsert({
      where: { sellerId: req.session!.userId },
      create: { sellerId: req.session!.userId, iban, holder: String(body.holder ?? '') },
      update: { iban, holder: String(body.holder ?? '') },
    });
    return { ok: true };
  }

  @Post('email')
  async changeEmail(@Req() req: SessionRequest, @Body() body: { email: string }) {
    const email = String(body.email ?? '').trim().toLowerCase();
    if (email.length > 254 || !EMAIL_PATTERN.test(email)) throw new BadRequestException('Invalid email');
    await this.prisma.user.update({ where: { id: req.session!.userId }, data: { email } });
    return { ok: true };
  }

  @Get('payout-account')
  async getPayoutAccount(@Req() req: SessionRequest) {
    const account = await this.prisma.payoutAccount.findUnique({ where: { sellerId: req.session!.userId } });
    return account ? { holder: account.holder, ibanLast4: account.iban.slice(-4) } : null;
  }
}
