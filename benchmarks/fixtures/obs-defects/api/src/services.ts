import { CaptureService } from './payments/capture.service';
import { CatalogSyncService } from './catalog/catalog-sync.service';
import { ChargesService } from './billing/charges.service';
import { CheckoutService } from './checkout/checkout.service';
import { DispatchAdapter } from './dispatch/dispatch.adapter';
import { ImportService } from './catalog/import.service';
import { NotificationsService } from './notifications/notifications.service';
import { OrdersService } from './orders/orders.service';
import { PriceService } from './pricing/price.service';
import { PromoService } from './promo/promo.service';
import { QuoteService } from './shipping/quote.service';
import { RefundService } from './orders/refund.service';
import { CarrierWebhookService } from './webhooks/carrier-webhook.service';

export const SERVICES = [
  CaptureService, CatalogSyncService, ChargesService, CheckoutService, DispatchAdapter, ImportService,
  NotificationsService, OrdersService, PriceService, PromoService, QuoteService, RefundService, CarrierWebhookService,
];
