import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { EXTENSION_SLUGS, ExtensionSlug } from '@shelfwise/contracts';
import { REQUIRED_MODULE } from './require-module.decorator';
import { SubscriptionsService } from '../billing/subscriptions.service';

@Injectable()
export class ExtensionModuleGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly subscriptions: SubscriptionsService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const key = this.reflector.getAllAndOverride<string | undefined>(REQUIRED_MODULE, [ctx.getHandler(), ctx.getClass()]);
    if (!key) return true;
    // Not an extension slug: ModuleEntitlementGuard judges coarse keys.
    if (!(EXTENSION_SLUGS as readonly string[]).includes(key)) return true;
    const { tenantId } = ctx.switchToHttp().getRequest().user;
    const active = await this.subscriptions.activeExtensions(tenantId);
    if (active.includes(key as ExtensionSlug)) return true;
    throw new ForbiddenException({ code: 'EXTENSION_NOT_PURCHASED', key });
  }
}
