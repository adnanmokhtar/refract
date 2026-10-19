import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import config from './mikro-orm.config';
import { OrdersModule } from './modules/orders/orders.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { CustomersModule } from './modules/customers/customers.module';
import { InventoryModule } from './modules/inventory/inventory.module';
import { ShippingModule } from './modules/shipping/shipping.module';
import { InvoicesModule } from './modules/invoices/invoices.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ReportsModule } from './modules/reports/reports.module';
import { WebhooksModule } from './modules/webhooks/webhooks.module';
import { AuditLogModule } from './modules/audit-log/audit-log.module';
import { RefundsModule } from './modules/refunds/refunds.module';

@Module({
  imports: [
    MikroOrmModule.forRoot(config),
    OrdersModule,
    PaymentsModule,
    CatalogModule,
    CustomersModule,
    InventoryModule,
    ShippingModule,
    InvoicesModule,
    NotificationsModule,
    AuthModule,
    UsersModule,
    ReportsModule,
    WebhooksModule,
    AuditLogModule,
    RefundsModule,
  ],
})
export class AppModule {}
