import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { AuthGuard } from './auth/auth.guard';
import { AuthModule } from './auth/auth.module';
import { ModuleEntitlementGuard } from './entitlements/module-entitlement.guard';
import { ExtensionModuleGuard } from './entitlements/extension-module.guard';
import { EntitlementsModule } from './entitlements/entitlements.module';
import { FeatureModules } from './feature-modules';

@Module({
  imports: [MikroOrmModule.forRoot(), EventEmitterModule.forRoot(), AuthModule, EntitlementsModule, ...FeatureModules],
  providers: [
    { provide: APP_GUARD, useClass: AuthGuard },
    // Two guards share the @RequireModule metadata: the first judges coarse module keys, the
    // second judges extension slugs. Each lets the other's keys through.
    { provide: APP_GUARD, useClass: ModuleEntitlementGuard },
    { provide: APP_GUARD, useClass: ExtensionModuleGuard },
  ],
})
export class AppModule {}
