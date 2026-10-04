import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { MikroORM } from '@mikro-orm/postgresql';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { ThrottlerStorageRedisService } from '@nest-lab/throttler-storage-redis';
import { GraphQLModule } from '@nestjs/graphql';
import { MercuriusDriver, MercuriusDriverConfig } from '@nestjs/mercurius';
import Redis from 'ioredis';

import ormConfig from './config/mikro-orm.config';
import { AuthModule } from './auth/auth.module';
import { CatalogModule } from './catalog/catalog.module';
import { createProductLoaders } from './catalog/product-loaders';
import { CheckoutModule } from './checkout/checkout.module';
import { HealthController } from './common/health.controller';
import { RedisModule } from './common/redis.module';
import { CustomersModule } from './customers/customers.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { GeoModule } from './geo/geo.module';
import { InvoicesModule } from './invoices/invoices.module';
import { OrdersModule } from './orders/orders.module';
import { PayoutsModule } from './payouts/payouts.module';
import { PickupModule } from './pickup/pickup.module';
import { RealtimeModule } from './realtime/realtime.module';
import { StaffModule } from './staff/staff.module';
import { StoresModule } from './stores/stores.module';
import { StorefrontModule } from './storefront/storefront.module';
import { WishlistModule } from './wishlist/wishlist.module';

@Module({
  imports: [
    MikroOrmModule.forRoot(ormConfig),
    ScheduleModule.forRoot(),

    // Public catalog and search endpoints (@UseGuards(ThrottlerGuard) on those controllers).
    ThrottlerModule.forRootAsync({
      useFactory: () => ({
        throttlers: [{ name: 'public', ttl: 60_000, limit: 120 }],
        storage: new ThrottlerStorageRedisService(new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379')),
      }),
    }),

    // Loaders are created per request so nothing they cache outlives it.
    GraphQLModule.forRootAsync<MercuriusDriverConfig>({
      driver: MercuriusDriver,
      inject: [MikroORM],
      useFactory: (orm: MikroORM) => ({
        autoSchemaFile: true,
        path: '/graphql',
        graphiql: process.env.NODE_ENV !== 'production',
        context: () => ({ loaders: createProductLoaders(orm.em.fork()) }),
      }),
    }),

    AuthModule,
    CatalogModule,
    CheckoutModule,
    CustomersModule,
    DashboardModule,
    GeoModule,
    InvoicesModule,
    OrdersModule,
    PayoutsModule,
    PickupModule,
    RealtimeModule,
    StaffModule,
    StoresModule,
    StorefrontModule,
    WishlistModule,
    RedisModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
