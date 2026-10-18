import { MikroOrmModule } from '@mikro-orm/nestjs';
import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ActivityService } from './common/activity.service';
import { JwtAuthGuard } from './common/jwt-auth.guard';
import { PermissionsGuard } from './common/permissions.guard';
import { RolesGuard } from './common/roles.guard';
import { SftpClient } from './common/sftp-client';
import { SessionStore } from './common/session-store';
import { TxRunner } from './common/tx-runner';
import { AuthController } from './auth/auth.controller';
import { CredentialsService } from './auth/credentials.service';
import { InvoicesController } from './invoices/invoices.controller';
import { InvoicesService } from './invoices/invoices.service';
import { StockController } from './inventory/stock.controller';
import { StockFeedExport } from './inventory/stock-feed.export';
import { StockRepository } from './inventory/stock.repository';
import { StockReservationService } from './inventory/stock-reservation.service';
import { StockService } from './inventory/stock.service';
import { InvoiceIssuedProcessor } from './jobs/invoice-issued.processor';
import { InvoiceSchedules } from './jobs/invoice-schedules';
import { Schedules } from './jobs/schedules';
import { TicketNotificationsSubscriber } from './notifications/ticket-notifications.subscriber';
import { OrderPlacementService } from './orders/order-placement.service';
import { OrderSubscriber } from './orders/order.subscriber';
import { OrdersController } from './orders/orders.controller';
import { OrdersService } from './orders/orders.service';
import { ReportsController } from './reports/reports.controller';
import { ReportsService } from './reports/reports.service';
import { TicketsController } from './tickets/tickets.controller';
import { TicketsService } from './tickets/tickets.service';
import { AccountsService } from './users/accounts.service';
import { AdminUsersController } from './users/admin-users.controller';
import { InternalAuthzController } from './users/internal-authz.controller';
import { MeController } from './users/me.controller';
import { UsersController } from './users/users.controller';
import { WalletsController } from './wallets/wallets.controller';
import { WalletActivitySubscriber } from './wallets/wallet-activity.subscriber';
import { WalletsService } from './wallets/wallets.service';

@Module({
  imports: [
    MikroOrmModule.forRoot(),
    // Crons run only in the single-replica v2-scheduler deployment (V1: ->onOneServer()).
    ...(process.env.SCHEDULER_ENABLED === 'true' ? [ScheduleModule.forRoot()] : []),
    BullModule.forRoot({ connection: { url: process.env.REDIS_URL } }),
    BullModule.registerQueue({ name: 'mail' }, { name: 'invoices' }),
  ],
  controllers: [
    AuthController,
    MeController,
    AdminUsersController,
    UsersController,
    InternalAuthzController,
    OrdersController,
    InvoicesController,
    WalletsController,
    StockController,
    TicketsController,
    ReportsController,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
    ActivityService,
    CredentialsService,
    SessionStore,
    SftpClient,
    TxRunner,
    AccountsService,
    OrdersService,
    OrderPlacementService,
    OrderSubscriber,
    InvoicesService,
    InvoiceIssuedProcessor,
    InvoiceSchedules,
    WalletsService,
    WalletActivitySubscriber,
    StockService,
    StockRepository,
    StockReservationService,
    StockFeedExport,
    TicketsService,
    TicketNotificationsSubscriber,
    ReportsService,
    Schedules,
  ],
})
export class AppModule {}
