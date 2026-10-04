import { IsString, MaxLength, MinLength } from 'class-validator';

export class LoginDto {
  @IsString()
  email: string;

  @IsString()
  password: string;
}

export class RegisterDto {
  @IsString()
  @MaxLength(254)
  email: string;

  @IsString()
  @MinLength(10)
  password: string;

  @IsString()
  @MaxLength(80)
  displayName: string;
}

export interface AuthUser {
  sub: string;
  email: string;
  role: 'BUYER' | 'SELLER' | 'ADMIN';
}
