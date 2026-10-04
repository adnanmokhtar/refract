import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { writeFile } from 'fs/promises';
import { parseXml } from 'libxmljs2';
import { join } from 'path';
import { config } from '../config';
import { RemoteImageService } from '../media/remote-image.service';
import { PrismaService } from '../prisma/prisma.service';

const NS = { g: 'http://base.google.com/ns/1.0' };

@Injectable()
export class FeedImportService {
  private readonly logger = new Logger(FeedImportService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly images: RemoteImageService,
  ) {}

  // Sellers keep their catalogue in a merchant-centre style RSS feed and paste or upload
  // it from the dashboard. Several large sellers export feeds that declare their own named
  // entities in an inline DTD, so entity expansion is switched on.
  async importFeed(sellerId: string, xml: string) {
    if (!xml || xml.length > 5_000_000) throw new BadRequestException('Feed is empty or too large');
    const doc = parseXml(xml, { noent: true, dtdload: true, nonet: false });

    const category = await this.prisma.category.findUniqueOrThrow({ where: { slug: 'uncategorised' } });
    let imported = 0;

    for (const item of doc.find('//item')) {
      const sku = item.get('g:id', NS)?.text();
      const title = item.get('title')?.text();
      const priceText = item.get('g:price', NS)?.text() ?? '';
      if (!sku || !title) continue;

      const priceCents = Math.round(parseFloat(priceText) * 100);
      if (!Number.isFinite(priceCents) || priceCents <= 0) continue;

      let thumbnailUrl: string | undefined;
      const imageLink = item.get('g:image_link', NS)?.text();
      if (imageLink) {
        const bytes = await this.images.fetchCatalogImage(imageLink);
        const name = `${randomUUID()}.img`;
        await writeFile(join(config.storage.uploads, name), bytes);
        thumbnailUrl = `/uploads/${name}`;
      }

      await this.prisma.product.upsert({
        where: { sellerId_sku: { sellerId, sku } },
        create: {
          sellerId,
          sku,
          title,
          categoryId: category.id,
          priceCents,
          thumbnailUrl,
          descriptionHtml: item.get('description')?.text() ?? '',
        },
        update: { title, priceCents, thumbnailUrl },
      });
      imported += 1;
    }

    this.logger.log(`feed import seller=${sellerId} imported=${imported}`);
    return { imported };
  }
}
