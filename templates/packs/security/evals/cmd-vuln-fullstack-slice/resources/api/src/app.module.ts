import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { AccountController } from './account/account.controller';
import { AdminController } from './admin/admin.controller';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { CartController } from './cart/cart.controller';
import { requestLogger } from './common/request-logger';
import { DebugController } from './debug/debug.controller';
import { InventoryController } from './inventory/inventory.controller';
import { StockTransfersService } from './inventory/stock-transfers.service';
import { InvoicesController } from './invoices/invoices.controller';
import { InvoicesService } from './invoices/invoices.service';
import { EmailTemplatesController } from './marketing/email-templates.controller';
import { EmailTemplatesService } from './marketing/email-templates.service';
import { ArchiveService } from './media/archive.service';
import { DownloadsController } from './media/downloads.controller';
import { RemoteImageService } from './media/remote-image.service';
import { ThumbnailService } from './media/thumbnail.service';
import { UploadsController } from './media/uploads.controller';
import { CheckoutService } from './orders/checkout.service';
import { CouponsService } from './orders/coupons.service';
import { OrdersController } from './orders/orders.controller';
import { OrdersService } from './orders/orders.service';
import { DiscountRulesService } from './pricing/discount-rules.service';
import { PrismaService } from './prisma/prisma.service';
import { FeedImportService } from './products/feed-import.service';
import { ProductsController } from './products/products.controller';
import { ProductsService } from './products/products.service';
import { CustomDomainService } from './settings/custom-domain.service';
import { SettingsController } from './settings/settings.controller';
import { StoreSettingsService } from './settings/store-settings.service';
import { ThemesController } from './themes/themes.controller';
import { ThemesService } from './themes/themes.service';
import { UsersController } from './users/users.controller';
import { UsersService } from './users/users.service';
import { SubscriptionsController } from './webhooks/subscriptions.controller';
import { WebhooksController } from './webhooks/webhooks.controller';

@Module({
  controllers: [
    AuthController,
    AccountController,
    AdminController,
    UsersController,
    ProductsController,
    OrdersController,
    InvoicesController,
    CartController,
    UploadsController,
    DownloadsController,
    ThemesController,
    EmailTemplatesController,
    SettingsController,
    WebhooksController,
    SubscriptionsController,
    InventoryController,
    DebugController,
  ],
  providers: [
    PrismaService,
    AuthService,
    UsersService,
    ProductsService,
    FeedImportService,
    OrdersService,
    CheckoutService,
    CouponsService,
    InvoicesService,
    DiscountRulesService,
    ArchiveService,
    ThumbnailService,
    RemoteImageService,
    ThemesService,
    EmailTemplatesService,
    StoreSettingsService,
    CustomDomainService,
    StockTransfersService,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(requestLogger).forRoutes('*');
  }
}
