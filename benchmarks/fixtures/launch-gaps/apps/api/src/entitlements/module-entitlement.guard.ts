import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { MODULE_KEYS, ModuleKey } from '@shelfwise/contracts';
import { REQUIRED_MODULE } from './require-module.decorator';
import { TenantModulesService } from './tenant-modules.service';

@Injectable()
export class ModuleEntitlementGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tenantModules: TenantModulesService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const key = this.reflector.getAllAndOverride<string | undefined>(REQUIRED_MODULE, [ctx.getHandler(), ctx.getClass()]);
    if (!key) return true;
    // Not a coarse key: ExtensionModuleGuard judges extension slugs.
    if (!(MODULE_KEYS as readonly string[]).includes(key)) return true;
    const { tenantId } = ctx.switchToHttp().getRequest().user;
    if (await this.tenantModules.isEnabled(tenantId, key as ModuleKey)) return true;
    throw new ForbiddenException({ code: 'MODULE_DISABLED', key });
  }
}
