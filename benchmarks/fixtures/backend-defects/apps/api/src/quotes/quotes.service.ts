import { Injectable } from '@nestjs/common';
import { QuotePreviewDto } from './quote-preview.dto';

@Injectable()
export class QuotesService {
  async preview(dto: QuotePreviewDto): Promise<{ subtotal: string; tax: string; total: string }> {
    const units = dto.lines.reduce((n, l) => n + l.quantity, 0);
    return { subtotal: `${units}.00`, tax: '0.00', total: `${units}.00` };
  }
}
