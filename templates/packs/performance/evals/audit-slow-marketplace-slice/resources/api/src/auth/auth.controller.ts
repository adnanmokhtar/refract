import { Body, Controller, HttpCode, Post, UnauthorizedException } from '@nestjs/common';
import { IsEmail, IsString, MaxLength } from 'class-validator';
import { AuthService } from './auth.service';
import { LoginRateLimiter } from './login-rate-limiter';

class LoginDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @MaxLength(200)
  password!: string;
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly limiter: LoginRateLimiter,
  ) {}

  @Post('login')
  @HttpCode(200)
  async login(@Body() dto: LoginDto) {
    this.limiter.assertAllowed(dto.email);
    const session = await this.auth.login(dto.email, dto.password);
    if (!session) {
      this.limiter.recordFailure(dto.email);
      throw new UnauthorizedException('Wrong email or password');
    }
    this.limiter.recordSuccess(dto.email);
    return session;
  }
}
