import { Body, Controller, Post } from '@nestjs/common';
import { QuotePreviewDto } from './quote-preview.dto';
import { QuotesService } from './quotes.service';

@Controller('quotes')
export class QuotesController {
  constructor(private readonly quotes: QuotesService) {}

  /** Price a basket without creating anything. */
  @Post('preview')
  async preview(@Body() dto: QuotePreviewDto): Promise<{ subtotal: string; tax: string; total: string }> {
    return this.quotes.preview(dto);
  }
}
