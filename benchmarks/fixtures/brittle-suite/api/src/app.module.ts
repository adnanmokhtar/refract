import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { PostgreSqlDriver } from '@mikro-orm/postgresql';
import { RefundsModule } from './refunds/refunds.module';
import { OrdersModule } from './orders/orders.module';
import { AdminModule } from './admin/admin.module';
import { CouponsModule } from './coupons/coupons.module';
import { WebhooksModule } from './webhooks/webhooks.module';

@Module({
  imports: [
    MikroOrmModule.forRoot({
      driver: PostgreSqlDriver,
      host: process.env.DATABASE_HOST,
      dbName: process.env.DATABASE_NAME,
      user: process.env.DATABASE_USER,
      password: process.env.DATABASE_PASSWORD,
      autoLoadEntities: true,
    }),
    RefundsModule,
    OrdersModule,
    AdminModule,
    CouponsModule,
    WebhooksModule,
  ],
})
export class AppModule {}
