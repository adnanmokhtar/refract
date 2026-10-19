import { Body, Controller, Get, HttpCode, Post, Query, Req, Res } from '@nestjs/common';
import { Request, Response } from 'express';
import { config } from '../config';
import { LoginDto, RegisterDto } from './auth.dto';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() body: RegisterDto) {
    return this.auth.register(body);
  }

  @Post('login')
  @HttpCode(200)
  async login(@Body() body: LoginDto, @Res({ passthrough: true }) res: Response) {
    const result = await this.auth.login(body.email, body.password);

    // The account pages still run on the cookie session; the SPA uses the bearer token.
    // SameSite=None because the seller dashboard is embedded on partner domains.
    res.cookie(config.auth.sessionCookie, result.sessionId, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: config.auth.sessionDays * 86_400_000,
    });

    return { accessToken: result.accessToken, user: result.user };
  }

  // Linked from the account pages and from partner embeds, which pass where to land
  // after sign-out.
  @Get('logout')
  async logout(
    @Req() req: Request,
    @Res() res: Response,
    @Query('returnTo') returnTo?: string,
  ) {
    await this.auth.revokeSession(req.cookies?.[config.auth.sessionCookie]);
    res.clearCookie(config.auth.sessionCookie);
    return res.redirect(returnTo || config.publicUrl);
  }
}
