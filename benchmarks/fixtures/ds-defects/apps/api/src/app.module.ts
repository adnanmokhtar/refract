import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { ScheduleModule } from '@nestjs/schedule';
import { CqrsModule } from '@nestjs/cqrs';
import { QueuesModule } from './queue/queues.module';
import { NotificationsModule } from './notifications/notifications.module';
import { OutboxModule } from './outbox/outbox.module';
import { OrdersModule } from './orders/orders.module';

@Module({
  imports: [
    MikroOrmModule.forRoot(),
    ScheduleModule.forRoot(),
    CqrsModule.forRoot(),
    QueuesModule,
    NotificationsModule,
    OutboxModule,
    OrdersModule,
  ],
})
export class AppModule {}
