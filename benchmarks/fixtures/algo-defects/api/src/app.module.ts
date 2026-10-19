import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { CatalogModule } from './catalog/catalog.module';
import { OrdersModule } from './orders/orders.module';

@Module({
  imports: [
    MikroOrmModule.forRoot({ clientUrl: process.env.DATABASE_URL, autoLoadEntities: true }),
    CatalogModule,
    OrdersModule,
  ],
})
export class AppModule {}
