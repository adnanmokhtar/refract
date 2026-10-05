import { CanActivate, ExecutionContext, ForbiddenException, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { TenantRequest } from './tenant.guard';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.get<string[]>(ROLES_KEY, context.getHandler()) ?? [];
    const req = context.switchToHttp().getRequest<TenantRequest>();
    if (required.every((role) => req.roles?.includes(role))) return true;
    throw new ForbiddenException();
  }
}
