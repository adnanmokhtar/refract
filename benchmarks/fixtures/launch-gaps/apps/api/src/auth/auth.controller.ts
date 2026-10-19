import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { Public } from './public.decorator';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('signup')
  signup(@Body() body: { email: string; password: string; storeName: string }) {
    return this.auth.signup(body);
  }

  @Public()
  @Post('login')
  login(@Body() body: { email: string; password: string }) {
    return this.auth.login(body);
  }

  /** The session user, their tenant and the tenant's plan. Roles live on the user record. */
  @Get('me')
  me(@Req() req: { user: { id: string } }) {
    return this.auth.profile(req.user.id);
  }
}
