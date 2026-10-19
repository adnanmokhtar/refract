import { Injectable, NotFoundException } from '@nestjs/common';
import { Money } from '../../shared/money/money';

@Injectable()
export class InvoicesService {
  private readonly totals = new Map<string, Money>();

  async renderTotal(invoiceId: string): Promise<string> {
    const total = this.totals.get(invoiceId);
    if (!total) {
      throw new NotFoundException(`invoice ${invoiceId} not found`);
    }
    return total.format();
  }
}
