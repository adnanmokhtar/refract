import { Controller, Get, Header, Param } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { NotFoundError } from '../common/errors';
import { renderInvoicePdf } from './invoice-pdf.renderer';

const COUNTRY_NAMES = new Map<string, string>([
  ['DE', 'Germany'],
  ['FR', 'France'],
  ['NL', 'Netherlands'],
  ['SE', 'Sweden'],
]);

// Shown on the PDF footer: the full country name when we have one, the ISO code otherwise.
export function countryLabel(code: string): string {
  return COUNTRY_NAMES.has(code) ? COUNTRY_NAMES.get(code)! : code;
}

// Invoice PDFs for the portal's "Download" button and the finance back office. The billing address
// is optional in the schema: customers on the free plan never entered one.
@Controller('invoices')
export class InvoicePdfController {
  constructor(private readonly db: PrismaClient) {}

  @Get(':id/pdf')
  @Header('content-type', 'application/pdf')
  async pdf(@Param('id') id: string): Promise<Buffer> {
    const invoice = await this.db.invoice.findUnique({ where: { id }, include: { customer: { include: { billingAddress: true } } } });
    if (!invoice) throw new NotFoundError('invoice', id);
    const country = invoice.customer.billingAddress!.country;
    return renderInvoicePdf({ number: invoice.number, totalCents: invoice.totalCents, currency: invoice.currency, country: countryLabel(country) });
  }
}
