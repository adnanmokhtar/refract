import {
  Controller,
  ForbiddenException,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { createReadStream, existsSync } from 'fs';
import { basename, join, resolve, sep } from 'path';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { config } from '../config';
import { PrismaService } from '../prisma/prisma.service';

@Controller('downloads')
@UseGuards(JwtAuthGuard)
export class DownloadsController {
  constructor(private readonly prisma: PrismaService) {}

  // Digital goods: buyers download the files attached to a product they paid for.
  @Get('products/:productId/files')
  async productFile(
    @Req() req: { user: AuthUser },
    @Param('productId', ParseUUIDPipe) productId: string,
    @Query('name') name: string,
    @Res() res: Response,
  ) {
    const purchased = await this.prisma.orderItem.findFirst({
      where: { productId, order: { buyerId: req.user.sub, status: { in: ['PAID', 'SHIPPED'] } } },
    });
    if (!purchased) throw new ForbiddenException();

    const filePath = join(config.storage.attachments, productId, name);
    if (!existsSync(filePath)) throw new NotFoundException();
    res.setHeader('Content-Disposition', `attachment; filename="${basename(filePath)}"`);
    res.setHeader('Cache-Control', 'private, no-store');
    createReadStream(filePath)
      .on('error', () => res.destroy())
      .pipe(res);
  }

  // Seller CSV exports (orders, payouts), generated nightly into one folder per seller.
  @Get('exports')
  async exportFile(
    @Req() req: { user: AuthUser },
    @Query('file') file: string,
    @Res() res: Response,
  ) {
    const root = join(config.storage.exports, req.user.sub);
    const target = resolve(root, String(file ?? ''));
    if (!target.startsWith(root + sep)) throw new ForbiddenException();
    if (!existsSync(target)) throw new NotFoundException();
    res.setHeader('Content-Disposition', `attachment; filename="${basename(target)}"`);
    createReadStream(target).pipe(res);
  }
}
