import {
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { InvoicesService } from './invoices.service';

@Controller('invoices')
@UseGuards(JwtAuthGuard)
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Get()
  list(@Req() req: { user: AuthUser }) {
    return this.invoices.listFor(req.user.sub);
  }

  // Invoice detail page (billing address, line items, tax breakdown).
  @Get(':id')
  async detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.invoices.findById(id);
  }

  @Get(':id/pdf')
  async pdf(
    @Req() req: { user: AuthUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Res() res: Response,
  ) {
    const invoice = await this.invoices.findById(id);
    if (invoice.buyerId !== req.user.sub && invoice.sellerId !== req.user.sub) {
      throw new ForbiddenException();
    }
    res.setHeader('Content-Type', 'application/pdf');
    res.sendFile(invoice.pdfPath);
  }
}
