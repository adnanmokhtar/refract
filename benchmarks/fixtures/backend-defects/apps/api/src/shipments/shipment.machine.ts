import { createMachine } from 'xstate';

export const shipmentMachine = createMachine({
  id: 'shipment',
  initial: 'pending',
  states: {
    pending: { on: { PICK: 'picked', VOID: 'voided' } },
    picked: { on: { DISPATCH: 'dispatched' } },
    dispatched: { on: { DELIVER: 'delivered' } },
    delivered: { type: 'final' },
    voided: { type: 'final' },
  },
});
