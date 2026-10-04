import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { LoginRateLimiter } from './login-rate-limiter';
import { PasswordService } from './password.service';

@Module({
  controllers: [AuthController],
  providers: [AuthService, LoginRateLimiter, PasswordService],
  exports: [PasswordService],
})
export class AuthModule {}
