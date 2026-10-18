import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS } from './permissions.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[]>(PERMISSIONS, [ctx.getHandler(), ctx.getClass()]);
    if (!required?.length) {
      return true;
    }

    const user = ctx.switchToHttp().getRequest().user;
    if (!required.every((p) => user?.permissions.includes(p))) {
      throw new ForbiddenException({ message: 'This action is unauthorized.' });
    }
    return true;
  }
}
