import { Module } from '@nestjs/common';
import { CustomersModule } from './customers/customers.module';
import { InvoicesModule } from './invoices/invoices.module';
import { OrdersModule } from './orders/orders.module';
import { ProductsModule } from './products/products.module';

@Module({ imports: [OrdersModule, CustomersModule, InvoicesModule, ProductsModule] })
export class AppModule {}
