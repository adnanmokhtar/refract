import { create } from 'xmlbuilder2';
import type { Invoice } from './invoice.entity';
import { formatMajor } from '../money/format';

interface UblLine {
  id: string;
  netMinor: number;
  vatMinor: number;
  rateBp: number;
}

/** UBL 2.1 invoices for EU business customers, issued by the API and sent over Peppol. */
export function buildUblInvoice(invoice: Invoice, lines: UblLine[]): string {
  const major = (minor: number) => formatMajor(minor, invoice.currency);
  const root = create({ version: '1.0' }).ele('Invoice', { xmlns: 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2' });
  root.ele('cbc:CustomizationID').txt('urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0');
  root.ele('cbc:ID').txt(invoice.number);
  root.ele('cbc:DocumentCurrencyCode').txt(invoice.currency);
  root.ele('cbc:TaxCurrencyCode').txt(invoice.currency);

  const lineVat = lines.map((l) => Math.round((l.netMinor * l.rateBp) / 10_000));
  const taxTotalMinor = lineVat.reduce((s, v) => s + v, 0);
  const categoryNetMinor = lines.reduce((s, l) => s + l.netMinor, 0);
  const categoryRateBp = lines[0]?.rateBp ?? 0;

  const taxTotal = root.ele('cac:TaxTotal');
  taxTotal.ele('cbc:TaxAmount', { currencyID: invoice.currency }).txt(major(taxTotalMinor));
  const sub = taxTotal.ele('cac:TaxSubtotal');
  sub.ele('cbc:TaxableAmount', { currencyID: invoice.currency }).txt(major(categoryNetMinor));
  sub.ele('cbc:TaxAmount', { currencyID: invoice.currency }).txt(major(Math.round((categoryNetMinor * categoryRateBp) / 10_000)));

  lines.forEach((l, i) => {
    const il = root.ele('cac:InvoiceLine');
    il.ele('cbc:ID').txt(l.id);
    il.ele('cbc:LineExtensionAmount', { currencyID: invoice.currency }).txt(major(l.netMinor));
    il.ele('cbc:TaxAmount', { currencyID: invoice.currency }).txt(major(lineVat[i]));
  });
  return root.end({ prettyPrint: true });
}
