import { createMachine } from 'xstate';

/** The order lifecycle. `cancelled` and `refunded` are terminal. */
export const orderMachine = createMachine({
  id: 'order',
  initial: 'open',
  states: {
    open: { on: { PAY: 'paid', CANCEL: 'cancelled' } },
    paid: { on: { SHIP: 'shipped', REFUND: 'refunded' } },
    shipped: { on: { REFUND: 'refunded' } },
    cancelled: { type: 'final' },
    refunded: { type: 'final' },
  },
});
