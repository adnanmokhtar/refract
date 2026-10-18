import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface AuthUser {
  id: number;
  accountId: number;
  name: string;
  email: string;
  roles: string[];
  permissions: string[];
}

export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext): AuthUser => ctx.switchToHttp().getRequest().user);
