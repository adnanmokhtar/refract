import { Router } from 'express';
import { listOrders } from './list';

export const ordersRouter = Router();
ordersRouter.get('/customers/:customerId/orders', listOrders);
