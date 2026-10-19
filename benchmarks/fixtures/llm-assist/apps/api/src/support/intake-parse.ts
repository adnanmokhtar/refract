import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { z } from 'zod';
import { LlmGatewayPort } from '../llm/llm-gateway.port';
import { ReturnRequestRow } from './return-request.entity';

export const RETURN_PROMPT_VERSION = 'return-request@2';

const ReturnRequest = z.object({
  orderNumber: z.string().nullable().default(null),
  reason: z.string().default('unspecified'),
  items: z.array(z.object({ sku: z.string(), quantity: z.number().int().positive() })).default([]),
});

const RETURN_JSON_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['orderNumber', 'reason', 'items'],
  properties: {
    orderNumber: { type: ['string', 'null'] },
    reason: { type: 'string' },
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['sku', 'quantity'],
        properties: { sku: { type: 'string' }, quantity: { type: 'integer' } },
      },
    },
  },
};

/** Turns a free-text return message into a draft return request. */
@Injectable()
export class ReturnIntakeService {
  constructor(
    private readonly gateway: LlmGatewayPort,
    private readonly em: EntityManager,
  ) {}

  async parse(tenantId: string, ticketId: string, message: string): Promise<ReturnRequestRow> {
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: 'Extract the return request from the customer message.' },
        { role: 'user', content: message },
      ],
      max_tokens: 400,
      response_format: { type: 'json_schema', json_schema: { name: 'return_request', strict: true, schema: RETURN_JSON_SCHEMA } },
    });
    if (reply.finishReason === 'length') throw new UnprocessableEntityException('Return message too long to parse');
    const request = ReturnRequest.parse(JSON.parse(reply.message.content as string ?? '{}'));
    const row = this.em.create(ReturnRequestRow, { tenantId, ticketId, ...request, promptVersion: RETURN_PROMPT_VERSION });
    await this.em.flush();
    return row;
  }
}
