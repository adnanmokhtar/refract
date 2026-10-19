import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { ReviewPromptsService } from '../catalog/review-prompts.service';
import { StorageService } from '../common/storage.service';
import { InvoiceListService } from '../invoices/invoice-list.service';
import { CarrierClient } from '../shipping/carrier.client';
import { RecommendationsClient } from '../storefront/recommendations.client';
import { Order } from './order.entity';

@Injectable()
export class OrderDetailService {
  constructor(
    private readonly em: EntityManager,
    private readonly carrier: CarrierClient,
    private readonly invoices: InvoiceListService,
    private readonly reviews: ReviewPromptsService,
    private readonly recs: RecommendationsClient,
    private readonly storage: StorageService,
  ) {}

  // GET /me/orders/:id — the buyer's order page: lines, live tracking, the invoice,
  // "review what you bought" prompts and a "you may also like" rail.
  async getDetail(orderId: string, buyerId: string) {
    const order = await this.em.findOneOrFail(Order, { id: orderId, buyer: buyerId }, { populate: ['items', 'store'] });
    const productIds = order.items.getItems().map((i) => i.product.id);

    const tracking = await this.carrier.tracking(order.shipmentRef);
    const invoice = await this.invoices.summaryForOrder(order.id);
    const reviewsDue = await this.reviews.pendingForProducts(buyerId, productIds);
    const recommendations = await this.recs.similarTo(productIds, { limit: 8 });

    return {
      id: order.id,
      number: order.number,
      status: order.status,
      store: { id: order.store.id, name: order.store.name, slug: order.store.slug },
      totalCents: Number(order.totalCents),
      currency: order.currency,
      lines: order.items.getItems().map((i) => ({
        productId: i.product.id,
        title: i.title,
        quantity: i.quantity,
        unitPriceCents: Number(i.unitPriceCents),
      })),
      tracking,
      invoice,
      reviewsDue,
      recommendations,
    };
  }

  // GET /me/orders/:id/invoice.pdf — redirects to a short-lived download link.
  async invoiceLink(orderId: string, buyerId: string): Promise<{ url: string }> {
    const invoice = await this.invoices.forOrder(orderId, buyerId);
    const signedUrl = await this.storage.signedUrl(invoice.pdfKey, { expiresInSeconds: 300 });
    return { url: signedUrl };
  }
}
