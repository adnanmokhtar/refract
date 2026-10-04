import type { Request, Response } from 'express';
import { metrics } from '../lib/metrics';
import { fetchShippingReport, fetchCarrierInvoice } from '../lib/reports';

// GET /exports/carrier/:shipmentId — the carrier invoice for one shipment. The shipment's
// manifest id is only known once the shipping report for it is back, so these two calls are
// ordered on purpose.
export async function exportCarrierInvoice(req: Request, res: Response) {
  const done = metrics.timer('orders.export_carrier');
  const report = await fetchShippingReport(req.params.shipmentId);
  const invoice = await fetchCarrierInvoice(report.manifestId);
  res.json({ invoice });
  done();
}
