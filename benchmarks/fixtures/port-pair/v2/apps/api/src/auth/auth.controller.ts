import { Body, Controller, HttpCode, Post, UnprocessableEntityException, ValidationPipe } from '@nestjs/common';
import { IsEmail, IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { Public } from '../common/public.decorator';
import { CredentialsService } from './credentials.service';

class TokenDto {
  @IsEmail()
  email!: string;

  @IsString()
  @IsNotEmpty()
  password!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  device_name!: string;
}

// Token login answers 400 on a malformed body, not V1's 422 (ADR-0006; the mobile app 3.x
// handles both, changes_baseline: auth.token-validation-status).
@Controller('auth')
export class AuthController {
  constructor(private readonly credentials: CredentialsService) {}

  @Public()
  @Post('token')
  @HttpCode(200)
  async token(@Body(new ValidationPipe({ whitelist: true })) body: TokenDto) {
    const user = await this.credentials.verify(body.email, body.password);
    if (!user) {
      // Wrong credentials keep V1's 422 envelope; only a malformed body answers 400 (ADR-0006).
      throw new UnprocessableEntityException({ message: 'The provided credentials are incorrect.', errors: { email: ['The provided credentials are incorrect.'] } });
    }
    return { token: await this.credentials.issueToken(user, body.device_name) };
  }
}
