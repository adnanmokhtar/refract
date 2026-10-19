import { ToolSpec } from '../../llm/llm-gateway.port';

const fn = (f: ToolSpec['function']): ToolSpec => ({ type: 'function', function: f });

export const ASSISTANT_TOOLS: ToolSpec[] = [
  fn({
    name: 'lookup_order',
    description: 'Look up an order by its number and return status, total and delivery estimate.',
    parameters: {
      type: 'object',
      properties: { tenantId: { type: 'string' }, orderNumber: { type: 'string' } },
      required: ['tenantId', 'orderNumber'],
    },
  }),
  fn({
    name: 'refund_order',
    description: 'Refund all or part of an order. Confirm with the customer first.',
    parameters: {
      type: 'object',
      properties: {
        orderNumber: { type: 'string' },
        amountMinor: { type: 'integer' },
        approved: { type: 'boolean', description: 'true once the customer said yes' },
      },
      required: ['orderNumber', 'amountMinor'],
    },
  }),
  fn({
    name: 'send_customer_email',
    description: 'Send an e-mail to the customer on the ticket.',
    parameters: {
      type: 'object',
      properties: { to: { type: 'string' }, subject: { type: 'string' }, body: { type: 'string' } },
      required: ['to', 'subject', 'body'],
    },
  }),
  fn({
    name: 'read_attachment',
    description: 'Read a file the customer attached to the ticket.',
    parameters: { type: 'object', properties: { path: { type: 'string' } }, required: ['path'] },
  }),
];
