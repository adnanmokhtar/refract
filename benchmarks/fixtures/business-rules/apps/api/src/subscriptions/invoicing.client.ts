import { Injectable } from '@nestjs/common';

@Injectable()
export class InvoicingClient {
  async credit(storeId: string, amountMinor: number, memo: string) {}
  async charge(storeId: string, amountMinor: number, memo: string) {}
}
