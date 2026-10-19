import { Global, Module } from '@nestjs/common';
import { EntitlementsService } from './entitlements.service';
import { TenantModulesService } from './tenant-modules.service';
import { SubscriptionsService } from '../billing/subscriptions.service';

@Global()
@Module({
  providers: [EntitlementsService, TenantModulesService, SubscriptionsService],
  exports: [EntitlementsService, TenantModulesService, SubscriptionsService],
})
export class EntitlementsModule {}
