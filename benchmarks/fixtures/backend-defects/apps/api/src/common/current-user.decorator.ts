import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface Principal {
  userId: string;
  tenantId: string;
  roles: string[];
}

/** The authenticated principal the auth guard attached to the request (server-derived, never the body). */
export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext): Principal => {
  const req = ctx.switchToHttp().getRequest<{ principal: Principal }>();
  return req.principal;
});
