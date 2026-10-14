import { Injectable } from '@nestjs/common';
import { sendUnaryData, ServerUnaryCall, status } from '@grpc/grpc-js';
import { RatesClient } from './rates.client';

export interface QuoteRequest {
  merchantId: string;
  weightKg: number;
  destinationCountry: string;
}

export interface QuoteReply {
  priceMinor: number;
  currency: string;
  carrier: string;
}

/**
 * The checkout service (another team) asks for a quote while the shopper waits; its own call budget is 800 ms.
 * Each quote fans out to the carriers' rate APIs.
 */
@Injectable()
export class QuotesGrpcService {
  constructor(private readonly rates: RatesClient) {}

  async getQuote(call: ServerUnaryCall<QuoteRequest, QuoteReply>, callback: sendUnaryData<QuoteReply>): Promise<void> {
    try {
      const offers = await this.rates.fetchAll(call.request.merchantId, call.request.weightKg, call.request.destinationCountry);
      const best = offers.sort((a, b) => a.priceMinor - b.priceMinor)[0];
      callback(null, { priceMinor: best.priceMinor, currency: best.currency, carrier: best.carrier });
    } catch (err) {
      callback({ code: status.UNAVAILABLE, message: String(err) });
    }
  }
}
