import { Injectable } from '@nestjs/common';
import { SpanKind, trace } from '@opentelemetry/api';
import { CarrierClient, Parcel, Quote } from '../integrations/carrier.client';

const tracer = trace.getTracer('shipping');

@Injectable()
export class QuoteService {
  constructor(private readonly carrier: CarrierClient) {}

  async quote(orderId: string, parcel: Parcel): Promise<Quote> {
    const span = tracer.startSpan('carrier.quote', { kind: SpanKind.CLIENT });
    span.setAttribute('order.id', orderId);
    try {
      const quote = await this.carrier.quote(parcel);
      span.end();
      return quote;
    } catch (e) {
      throw e;
    }
  }
}
