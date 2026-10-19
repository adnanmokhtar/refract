import { createMachine } from 'xstate';

export const shipmentMachine = createMachine({
  id: 'shipment',
  initial: 'label_created',
  states: {
    label_created: { on: { PICK_UP: 'in_transit', CANCEL: 'cancelled' } },
    in_transit: { on: { DELIVER: 'delivered', LOSE: 'lost' } },
    delivered: { type: 'final' },
    lost: { type: 'final' },
    cancelled: { type: 'final' },
  },
});
