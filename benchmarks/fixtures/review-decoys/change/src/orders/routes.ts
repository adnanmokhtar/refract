import { Router } from 'express';
import { listOrders } from './list';
import { listOrderSummaries } from './list-summary';
import { createRefund } from './refunds';
import { adjustRefund } from './refund-audit';
import { exportOrders, exportMonth } from './export';
import { exportCarrierInvoice } from './export-carrier';

export const ordersRouter = Router();
ordersRouter.get('/customers/:customerId/orders', listOrders);
ordersRouter.get('/customers/:customerId/order-summaries', listOrderSummaries);
ordersRouter.post('/orders/:id/refunds', createRefund);
ordersRouter.post('/orders/:id/refund-adjustments', adjustRefund);
ordersRouter.get('/exports/orders.json', exportOrders);
ordersRouter.get('/exports/month/:month', exportMonth);
ordersRouter.get('/exports/carrier/:shipmentId', exportCarrierInvoice);
