import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { writeFile } from 'fs/promises';
import { join } from 'path';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { config } from '../config';
import { RemoteImageService } from '../media/remote-image.service';
import { FeedImportService } from './feed-import.service';
import { ProductsService, SearchParams } from './products.service';

@Controller('products')
export class ProductsController {
  constructor(
    private readonly products: ProductsService,
    private readonly feeds: FeedImportService,
    private readonly remoteImages: RemoteImageService,
  ) {}

  @Get()
  search(@Query() query: SearchParams) {
    return this.products.search(query);
  }

  @Get(':id')
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const product = await this.products.findOne(id);
    const related = await this.products.related(product.id, product.sellerId);
    return { ...product, related };
  }

  // Product editor: "Add image from URL".
  @Post(':id/images/from-url')
  @UseGuards(JwtAuthGuard)
  async addImageFromUrl(
    @Req() req: { user: AuthUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: { url: string },
  ) {
    const bytes = await this.remoteImages.fetchSellerImage(body.url);
    const name = `${randomUUID()}.img`;
    await writeFile(join(config.storage.uploads, name), bytes);
    return this.products.addImage(id, req.user.sub, `/uploads/${name}`);
  }

  // Catalogue sync from the seller's XML product feed.
  @Post('feed')
  @UseGuards(JwtAuthGuard)
  importFeed(@Req() req: { user: AuthUser }, @Body() body: { xml: string }) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.feeds.importFeed(req.user.sub, body.xml);
  }
}
