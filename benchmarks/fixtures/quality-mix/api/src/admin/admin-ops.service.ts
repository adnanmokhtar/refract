import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { ChargesService } from '../billing/charges.service';
import { ProviderClient } from '../billing/provider.client';
import { BillingService } from '../billing/billing.service';
import { renderInvoicePdf } from '../billing/invoice-pdf.renderer';
import { buildInvoiceLines, invoiceTotalCents } from '../billing/invoice-lines';
import { billingAnchorDay } from '../billing/billing-anchor';
import { computeTax } from '../billing/tax';
import { prorate } from '../billing/proration';
import { invoiceNumber } from '../invoices/invoice-number';
import { InvoiceListService } from '../invoices/invoice-list.service';
import { isOpen } from '../invoices/invoice.model';
import { statusBadge } from '../invoices/invoice-status';
import { CheckoutService } from '../checkout/checkout.service';
import { LedgerClient } from '../checkout/ledger.client';
import { RefundBatchService } from '../refunds/refund-batch.service';
import { SubscriptionStatus, statusLabel } from '../subscriptions/subscription-status';
import { RenewalService } from '../subscriptions/renewal.service';
import { canUseMeteredBilling, seatLimit } from '../subscriptions/feature-gate';
import { PlanChangeService } from '../subscriptions/plan-change.service';
import { normalizeCouponCode } from '../coupons/coupon-code';
import { CreditTransferService, Wallet } from '../wallet/credit-transfer.service';
import { UsageService } from '../usage/usage.service';
import { admitUsage } from '../usage/quota';
import { retentionCutoff } from '../usage/retention';
import { toMinorUnits } from '../payouts/minor-units';
import { sniffDialect } from '../imports/csv-dialect';
import { OrderImportConsumer } from '../imports/order-import.consumer';
import { seatPrice } from '../domain/pricing';
import { RevenueReportService } from '../reports/revenue-report.service';
import { CustomersService } from '../customers/customers.service';
import { NotFoundError, ValidationError } from '../common/errors';
import { log } from '../lib/logger';
import { legacyCharge } from '../lib/sdk-shim';

// Back-office operations for the support and finance teams. Every admin screen calls into here.
@Injectable()
export class AdminOpsService {
  constructor(
    private readonly db: PrismaClient,
    private readonly charges: ChargesService,
    private readonly provider: ProviderClient,
    private readonly billing: BillingService,
    private readonly invoices: InvoiceListService,
    private readonly checkout: CheckoutService,
    private readonly ledger: LedgerClient,
    private readonly refunds: RefundBatchService,
    private readonly renewals: RenewalService,
    private readonly planChanges: PlanChangeService,
    private readonly wallets: CreditTransferService,
    private readonly usage: UsageService,
    private readonly orderImports: OrderImportConsumer,
    private readonly reports: RevenueReportService,
    private readonly customers: CustomersService,
  ) {}

  // --- invoices ------------------------------------------------------------------------------
  async reissueInvoice(invoiceId: string): Promise<Buffer> {
    const invoice = await this.db.invoice.findUnique({ where: { id: invoiceId } });
    if (!invoice) throw new NotFoundError('invoice', invoiceId);
    const lines = buildInvoiceLines({ description: 'Plan', amountCents: invoice.totalCents }, []);
    const number = invoiceNumber(new Date(), Number(invoice.number.split('-').pop()));
    return renderInvoicePdf({ number, totalCents: invoiceTotalCents(lines), currency: invoice.currency, country: 'DE' });
  }

  async openInvoiceBadges(customerId: string): Promise<string[]> {
    const page = await this.invoices.list(customerId, 1, 50);
    return page.items.map((i) => statusBadge({ ...i, status: 'open' })).filter((_, idx) => isOpen({ ...page.items[idx], status: 'open' }));
  }

  // --- refunds and credit -----------------------------------------------------------------------
  async refundCharges(chargeIds: string[], amountCents: number): Promise<string[]> {
    return this.refunds.refundAll(chargeIds.map((chargeId) => ({ chargeId, amountCents })));
  }

  async grantGoodwillCredit(customerWallet: Wallet, promoWallet: Wallet, amountCents: number): Promise<void> {
    if (amountCents > 50_000) throw new ValidationError('goodwill credit above 500.00 needs finance approval', ['amountCents']);
    await this.wallets.topUp(customerWallet, promoWallet, amountCents);
    await this.ledger.post(`goodwill:${customerWallet.id}`, '6100-goodwill', amountCents);
  }

  // --- subscriptions ------------------------------------------------------------------------------
  async forceRenewal(subscriptionId: string): Promise<void> {
    await this.renewals.chargeNow(subscriptionId);
  }

  describeSubscription(status: SubscriptionStatus, plan: 'free' | 'trial' | 'starter' | 'growth' | 'enterprise'): string {
    return `${statusLabel(status)} · ${seatLimit(plan)} seats · metered ${canUseMeteredBilling(plan) ? 'on' : 'off'}`;
  }

  // Finance compares the selectable rule with the calendar rule while customers migrate.
  migrationCredit(oldPriceCents: number, start: Date, end: Date): { current: number; calendar: number } {
    const today = new Date();
    return { current: this.planChanges.creditFor(oldPriceCents, start, end, today), calendar: prorate(oldPriceCents, start, end, today) };
  }

  anchorDayFor(startDate: string): number {
    return billingAnchorDay(startDate);
  }

  // --- pricing, tax and payouts -----------------------------------------------------------------------
  quoteSeats(seats: number, country: string): { netCents: number; taxCents: number } {
    const net = seatPrice([{ upToSeats: 10, unitCents: 1_200 }, { upToSeats: 100, unitCents: 900 }], seats).toNumber();
    return { netCents: net, taxCents: computeTax({ netCents: net, country, sellerCountry: 'DE' }) };
  }

  payoutMinor(merchantId: string, currency: string, amount: number): number {
    return toMinorUnits({ merchantId, currency, amount });
  }

  // --- usage -----------------------------------------------------------------------------------------
  async resetUsage(accountId: string): Promise<void> {
    await this.db.$executeRaw`update usage_account set used = 0 where id = ${accountId}`;
    log.log(`usage reset for ${accountId}; retention cutoff ${retentionCutoff(90).toISOString()}`);
  }

  wouldAdmit(plan: string, quota: number, used: number, units: number): boolean {
    return admitUsage({ plan, quota, usedUnits: used }, units).admitted;
  }

  async usageExport(accountId: string) {
    return this.usage.export(accountId, 1_000);
  }

  // --- imports, coupons, reports, checkout ------------------------------------------------------------
  async replayOrderImport(body: string): Promise<void> {
    await this.orderImports.handle({ id: `replay-${Date.now()}`, body });
  }

  describeCsv(sample: string): string {
    const d = sniffDialect(sample);
    return `delimiter ${JSON.stringify(d.delimiter)}, header ${d.hasHeader}, decimal comma ${d.decimalComma}`;
  }

  canonicalCoupon(raw: string): string {
    return normalizeCouponCode(raw);
  }

  async rebuildRevenueReport(month: string) {
    return this.reports.build(month);
  }

  async rebookOrder(orderId: string, accountCode: string, amountCents: number) {
    return this.checkout.book(orderId, [{ sku: 'manual', accountCode, amountCents }]);
  }

  async customerCharges(customerId: string) {
    await this.customers.get(customerId);
    return this.charges.listCharges(customerId);
  }

  // Merchants still on the v8 SDK integration are charged through the shim.
  async legacyRecharge(sdk: { request(opts: unknown): Promise<unknown> }, customerRef: string, amountCents: number) {
    return legacyCharge(sdk, { customer: customerRef, amount: amountCents });
  }

  async providerRefund(chargeId: string, amountCents: number) {
    const refund = await this.provider.refund(chargeId, amountCents);
    this.billing.recordFailure(chargeId, `manual refund ${refund.id}`);
    return refund;
  }
}
